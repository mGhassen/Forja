//! Seekable CDN proxy for 111477-style signed URLs (chunk cache + single upstream GET).

use axum::{
    body::Body,
    extract::{Request, State},
    http::{header, StatusCode},
    response::Response,
    routing::get,
    Router,
};
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;
use tokio::fs::{self, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use tokio::io::SeekFrom;
use tokio::sync::{Notify, RwLock};

const CHUNK_SIZE: u64 = 4 * 1024 * 1024;
const RECONNECT_DELAY_MS: u64 = 1500;
const MAX_RECONNECTS: u32 = 20;
const MAX_REDIRECTS: u32 = 8;
const FIRST_BYTE_TIMEOUT_MS: u64 = 90_000;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Seek111477StartRequest {
    pub upstream_url: String,
    #[serde(default)]
    pub headers: HashMap<String, String>,
    pub cache_dir: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Seek111477StartResponse {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Clone)]
struct FileMeta {
    length: u64,
    content_type: String,
}

#[derive(Clone)]
struct SharedState {
    target_url: Arc<RwLock<String>>,
    cache_key_dir: PathBuf,
    meta: Arc<RwLock<Option<FileMeta>>>,
    chunk_bytes: Arc<RwLock<HashMap<u32, u32>>>,
    current_read_offset: Arc<AtomicU64>,
    stopping: Arc<AtomicBool>,
    byte_notify: Arc<Notify>,
    client: reqwest::Client,
    extra_headers: HashMap<String, String>,
}

pub struct Seek111477Proxy {
    port: u16,
    shutdown: Option<tokio::sync::oneshot::Sender<()>>,
    state: Arc<SharedState>,
    downloader: Option<tokio::task::JoinHandle<()>>,
}

impl Seek111477Proxy {
    pub async fn start(req: Seek111477StartRequest) -> Result<Self, String> {
        let cache_dir = PathBuf::from(&req.cache_dir);
        fs::create_dir_all(&cache_dir)
            .await
            .map_err(|e| format!("cache_dir: {e}"))?;

        let hash = fnv1a_hex(&req.upstream_url);
        let cache_key_dir = cache_dir.join(&hash);
        fs::create_dir_all(&cache_key_dir)
            .await
            .map_err(|e| format!("cache_key_dir: {e}"))?;

        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .cookie_store(true)
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|e| e.to_string())?;

        let mut extra_headers = HashMap::from([(
            "User-Agent".into(),
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
             (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
                .into(),
        )]);
        extra_headers.extend(req.headers);

        let state = Arc::new(SharedState {
            target_url: Arc::new(RwLock::new(req.upstream_url.clone())),
            cache_key_dir,
            meta: Arc::new(RwLock::new(None)),
            chunk_bytes: Arc::new(RwLock::new(HashMap::new())),
            current_read_offset: Arc::new(AtomicU64::new(0)),
            stopping: Arc::new(AtomicBool::new(false)),
            byte_notify: Arc::new(Notify::new()),
            client,
            extra_headers,
        });

        let meta = probe(&state).await?;
        *state.meta.write().await = Some(meta.clone());
        scan_existing_chunks(&state).await;

        let app_state = state.clone();
        let app = Router::new()
            .route("/", get(serve_root).head(serve_root))
            .with_state(app_state);

        let listener = tokio::net::TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], 0)))
            .await
            .map_err(|e| e.to_string())?;
        let port = listener.local_addr().map_err(|e| e.to_string())?.port();
        let (tx, rx) = tokio::sync::oneshot::channel();

        tokio::spawn(async move {
            let _ = axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = rx.await;
                })
                .await;
        });

        let downloader = spawn_downloader(state.clone());

        let deadline =
            tokio::time::Instant::now() + Duration::from_millis(FIRST_BYTE_TIMEOUT_MS);
        while !has_byte(&state, 0).await {
            if state.stopping.load(Ordering::Relaxed) {
                return Err("stopped before first byte".into());
            }
            if tokio::time::Instant::now() >= deadline {
                return Err("no upstream bytes within 90s".into());
            }
            tokio::time::sleep(Duration::from_millis(200)).await;
        }

        Ok(Self {
            port,
            shutdown: Some(tx),
            state,
            downloader: Some(downloader),
        })
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    pub fn url(&self) -> String {
        format!("http://127.0.0.1:{}/", self.port)
    }

    pub async fn stop(mut self) {
        self.state.stopping.store(true, Ordering::Relaxed);
        self.state.byte_notify.notify_waiters();
        if let Some(tx) = self.shutdown.take() {
            let _ = tx.send(());
        }
        if let Some(handle) = self.downloader.take() {
            handle.abort();
        }
        let _ = fs::remove_dir_all(&self.state.cache_key_dir).await;
    }
}

pub async fn purge_cache(cache_dir: &str) -> Result<(), String> {
    let path = Path::new(cache_dir);
    if path.exists() {
        fs::remove_dir_all(path)
            .await
            .map_err(|e| format!("purge: {e}"))?;
    }
    Ok(())
}

fn fnv1a_hex(s: &str) -> String {
    const OFFSET: u64 = 0xcbf29ce484222325;
    const PRIME: u64 = 0x100000001b3;
    let mut h = OFFSET;
    for b in s.as_bytes() {
        h ^= *b as u64;
        h = h.wrapping_mul(PRIME);
    }
    format!("{h:016x}")
}

async fn probe(state: &SharedState) -> Result<FileMeta, String> {
    // Lock page may appear after a.111477 → p.111477/bulk → workers.dev/d/...
    // Auto-solve math captcha (POST /unlock/{linkId}) then retry.
    for attempt in 0..4 {
        let resp = follow_redirects(
            state,
            reqwest::Method::GET,
            HashMap::from([("Range".into(), "bytes=0-0".into())]),
        )
        .await?;
        let status = resp.status().as_u16();
        let ct = resp
            .headers()
            .get(header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("application/octet-stream")
            .to_string();
        let cr = resp
            .headers()
            .get(header::CONTENT_RANGE)
            .and_then(|v| v.to_str().ok())
            .map(str::to_string);
        let cl = resp
            .headers()
            .get(header::CONTENT_LENGTH)
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.parse::<u64>().ok());
        let body = resp.text().await.unwrap_or_default();
        if looks_like_html(status, &body) {
            let page_url = state.target_url.read().await.clone();
            if try_unlock_download_lock(state, &body, &page_url).await? {
                continue;
            }
            if body.to_ascii_lowercase().contains("just a moment")
                || body.to_ascii_lowercase().contains("cf-mitigated")
                || body.contains("challenge-platform")
            {
                return Err(format!(
                    "upstream Cloudflare challenge (attempt {attempt}): open once in browser or retry"
                ));
            }
            return Err(format!(
                "upstream returned HTML (not a media file; attempt {attempt})"
            ));
        }
        if status == 429 {
            return Err(format!("upstream 429: {}", body.trim()));
        }
        if let Some(cr) = cr {
            if let Some(m) = cr.rsplit('/').next() {
                if let Ok(len) = m.trim().parse::<u64>() {
                    return Ok(FileMeta {
                        length: len,
                        content_type: ct,
                    });
                }
            }
        }
        if let Some(len) = cl {
            if len > 0 {
                return Ok(FileMeta {
                    length: len,
                    content_type: ct,
                });
            }
        }
        return Err("cannot determine content-length".into());
    }
    Err("download lock unlock failed after retries".into())
}

fn looks_like_html(status: u16, body: &str) -> bool {
    if status == 200 && body.trim_start().starts_with("<!") {
        return true;
    }
    body.to_ascii_lowercase().contains("<html")
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct DownloadLockChallenge {
    link_id: String,
    token: String,
    retry_url: String,
    answer: i64,
}

fn html_hidden_value(html: &str, id: &str) -> Option<String> {
    // id= then value=, or value= then id=
    let patterns = [
        format!(r#"id=["']{id}["'][^>]*value=["']([^"']*)["']"#),
        format!(r#"value=["']([^"']*)["'][^>]*id=["']{id}["']"#),
    ];
    for pat in patterns {
        if let Ok(re) = regex::Regex::new(&pat) {
            if let Some(c) = re.captures(html) {
                if let Some(m) = c.get(1) {
                    let v = m.as_str().trim();
                    if !v.is_empty() {
                        return Some(v.to_string());
                    }
                }
            }
        }
    }
    None
}

fn parse_download_lock(html: &str) -> Option<DownloadLockChallenge> {
    let lower = html.to_ascii_lowercase();
    if !(lower.contains("download locked")
        || lower.contains("captchaform")
        || html.contains("/unlock/")
        || lower.contains("force-release the lock"))
    {
        return None;
    }
    let link_id = html_hidden_value(html, "linkId")?;
    let token = html_hidden_value(html, "token")?;
    let retry_url = html_hidden_value(html, "retryUrl")?;
    let math = regex::Regex::new(r"(\d+)\s*\+\s*(\d+)\s*=")
        .ok()?
        .captures(html)?;
    let a: i64 = math.get(1)?.as_str().parse().ok()?;
    let b: i64 = math.get(2)?.as_str().parse().ok()?;
    Some(DownloadLockChallenge {
        link_id,
        token,
        retry_url,
        answer: a + b,
    })
}

async fn try_unlock_download_lock(
    state: &SharedState,
    html: &str,
    page_url: &str,
) -> Result<bool, String> {
    let Some(lock) = parse_download_lock(html) else {
        return Ok(false);
    };
    let page = reqwest::Url::parse(page_url).map_err(|e| e.to_string())?;
    let unlock_url = format!(
        "{}://{}/unlock/{}",
        page.scheme(),
        page.host_str().unwrap_or(""),
        lock.link_id
    );
    let body = serde_json::json!({
        "answer": lock.answer,
        "token": lock.token,
    });
    let mut req = state
        .client
        .post(&unlock_url)
        .header(header::CONTENT_TYPE, "application/json")
        .header(header::REFERER, page_url)
        .header(header::ORIGIN, format!("{}://{}", page.scheme(), page.host_str().unwrap_or("")))
        .json(&body);
    for (k, v) in &state.extra_headers {
        // Don't override Content-Type / Referer we set for unlock.
        let lk = k.to_ascii_lowercase();
        if lk == "content-type" || lk == "referer" || lk == "origin" {
            continue;
        }
        req = req.header(k, v);
    }
    let resp = req.send().await.map_err(|e| format!("unlock POST: {e}"))?;
    let status = resp.status().as_u16();
    let data: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| format!("unlock JSON: {e}"))?;
    if status >= 200 && status < 300 && data.get("ok").and_then(|v| v.as_bool()) == Some(true) {
        *state.target_url.write().await = lock.retry_url;
        return Ok(true);
    }
    let err = data
        .get("error")
        .and_then(|v| v.as_str())
        .unwrap_or("unlock rejected");
    Err(format!("download lock unlock failed ({status}): {err}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_lock_math_and_fields() {
        let html = r#"
        <h1>Download Locked</h1>
        <div class="question">9 + 4 = ?</div>
        <form id="captchaForm">
          <input type="hidden" id="token" value="1787523401:d572a86fdc14f7b4">
          <input type="hidden" id="linkId" value="1aa989411275f6a2d15e3021e75d48ba">
          <input type="hidden" id="retryUrl" value="https://cdn.example/d/abc/file.mkv">
          <button type="submit">Unlock &amp; Retry</button>
        </form>
        <script>fetch('/unlock/' + linkId, { method: 'POST' })</script>
        "#;
        let lock = parse_download_lock(html).expect("parse");
        assert_eq!(lock.answer, 13);
        assert_eq!(lock.link_id, "1aa989411275f6a2d15e3021e75d48ba");
        assert_eq!(lock.token, "1787523401:d572a86fdc14f7b4");
        assert_eq!(lock.retry_url, "https://cdn.example/d/abc/file.mkv");
    }

    #[test]
    fn non_lock_html_is_none() {
        assert!(parse_download_lock("<html><body>hello</body></html>").is_none());
    }

    #[test]
    fn fnv_stable() {
        assert_eq!(
            fnv1a_hex("https://example.com/a"),
            fnv1a_hex("https://example.com/a")
        );
    }

    #[test]
    fn parse_range_open_end() {
        let (s, e) = parse_range("bytes=0-", 1000).unwrap();
        assert_eq!(s, 0);
        assert_eq!(e, 999);
    }
}

async fn follow_redirects(
    state: &SharedState,
    mut method: reqwest::Method,
    headers: HashMap<String, String>,
) -> Result<reqwest::Response, String> {
    let mut url = state.target_url.read().await.clone();
    for _ in 0..=MAX_REDIRECTS {
        let mut req = state.client.request(method.clone(), &url);
        for (k, v) in &state.extra_headers {
            req = req.header(k, v);
        }
        for (k, v) in &headers {
            req = req.header(k, v);
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        if (300..400).contains(&status) {
            if let Some(loc) = resp.headers().get(header::LOCATION) {
                let loc = loc.to_str().map_err(|e| e.to_string())?;
                url = reqwest::Url::parse(&url)
                    .map_err(|e| e.to_string())?
                    .join(loc)
                    .map_err(|e| e.to_string())?
                    .to_string();
                if status == 303 {
                    method = reqwest::Method::GET;
                }
                continue;
            }
        }
        if url != *state.target_url.read().await {
            *state.target_url.write().await = url;
        }
        return Ok(resp);
    }
    Err("too many redirects".into())
}

async fn scan_existing_chunks(state: &SharedState) {
    let mut map = state.chunk_bytes.write().await;
    map.clear();
    let Ok(mut rd) = fs::read_dir(&state.cache_key_dir).await else {
        return;
    };
    while let Ok(Some(entry)) = rd.next_entry().await {
        let name = entry.file_name().to_string_lossy().into_owned();
        if let Some(idx) = name
            .strip_prefix("chunk_")
            .and_then(|s| s.strip_suffix(".bin"))
            .and_then(|s| s.parse::<u32>().ok())
        {
            if let Ok(meta) = entry.metadata().await {
                map.insert(idx, meta.len() as u32);
            }
        }
    }
}

fn chunk_index(pos: u64) -> u32 {
    (pos / CHUNK_SIZE) as u32
}

fn chunk_start(idx: u32) -> u64 {
    idx as u64 * CHUNK_SIZE
}

async fn chunk_expected_size(state: &SharedState, idx: u32) -> u32 {
    let meta = state.meta.read().await;
    let Some(m) = meta.as_ref() else {
        return CHUNK_SIZE as u32;
    };
    let start = chunk_start(idx);
    let remaining = m.length.saturating_sub(start);
    std::cmp::min(remaining, CHUNK_SIZE) as u32
}

fn chunk_path(state: &SharedState, idx: u32) -> PathBuf {
    state
        .cache_key_dir
        .join(format!("chunk_{idx:07}.bin"))
}

async fn has_byte(state: &SharedState, pos: u64) -> bool {
    let meta = state.meta.read().await;
    let Some(m) = meta.as_ref() else {
        return false;
    };
    if pos >= m.length {
        return false;
    }
    let idx = chunk_index(pos);
    let off = (pos - chunk_start(idx)) as u32;
    let bytes = state.chunk_bytes.read().await.get(&idx).copied().unwrap_or(0);
    bytes > off
}

async fn add_range(state: &SharedState, start: u64, end: u64) {
    if end < start {
        return;
    }
    let mut pos = start;
    let mut changed = false;
    let mut map = state.chunk_bytes.write().await;
    while pos <= end {
        let idx = chunk_index(pos);
        let c_start = chunk_start(idx);
        let c_expected = chunk_expected_size(state, idx).await;
        let c_last = c_start + c_expected as u64 - 1;
        let seg_end = end.min(c_last);
        let new_bytes = (seg_end - c_start + 1) as u32;
        let entry = map.entry(idx).or_insert(0);
        if new_bytes > *entry {
            *entry = new_bytes;
            changed = true;
        }
        pos = seg_end + 1;
    }
    drop(map);
    if changed {
        state.byte_notify.notify_waiters();
    }
}

async fn wait_for_byte(state: &SharedState, pos: u64) {
    while !has_byte(state, pos).await {
        if state.stopping.load(Ordering::Relaxed) {
            return;
        }
        tokio::time::timeout(Duration::from_millis(500), state.byte_notify.notified())
            .await
            .ok();
    }
}

fn spawn_downloader(state: Arc<SharedState>) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        let mut write_offset = 0u64;
        let mut attempt = 0u32;
        while !state.stopping.load(Ordering::Relaxed) && attempt <= MAX_RECONNECTS {
            let total = {
                let m = state.meta.read().await;
                m.as_ref().map(|x| x.length).unwrap_or(0)
            };
            if write_offset >= total {
                return;
            }
            let url = state.target_url.read().await.clone();
            let mut req = state.client.get(&url).header("Range", format!("bytes={write_offset}-"));
            for (k, v) in &state.extra_headers {
                req = req.header(k, v);
            }
            let resp = match req.send().await {
                Ok(r) => r,
                Err(_) => {
                    attempt += 1;
                    tokio::time::sleep(Duration::from_millis(RECONNECT_DELAY_MS * attempt as u64))
                        .await;
                    continue;
                }
            };
            let status = resp.status().as_u16();
            if status != 200 && status != 206 {
                attempt += 1;
                tokio::time::sleep(Duration::from_millis(RECONNECT_DELAY_MS)).await;
                continue;
            }
            let ct = resp
                .headers()
                .get(header::CONTENT_TYPE)
                .and_then(|v| v.to_str().ok())
                .unwrap_or("")
                .to_ascii_lowercase();
            // Concurrent-download lock page can reappear on reconnect.
            if ct.contains("text/html") {
                let body = resp.text().await.unwrap_or_default();
                let page_url = state.target_url.read().await.clone();
                match try_unlock_download_lock(&state, &body, &page_url).await {
                    Ok(true) => {
                        attempt = 0;
                        continue;
                    }
                    Ok(false) | Err(_) => {
                        attempt += 1;
                        tokio::time::sleep(Duration::from_millis(RECONNECT_DELAY_MS)).await;
                        continue;
                    }
                }
            }
            attempt = 0;
            let mut stream = resp.bytes_stream();
            let mut pos = write_offset;
            while let Some(chunk) = stream.next().await {
                if state.stopping.load(Ordering::Relaxed) {
                    return;
                }
                let chunk = match chunk {
                    Ok(c) => c,
                    Err(_) => break,
                };
                if chunk.is_empty() {
                    continue;
                }
                let idx = chunk_index(pos);
                let path = chunk_path(&state, idx);
                if let Some(parent) = path.parent() {
                    let _ = fs::create_dir_all(parent).await;
                }
                let mut file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&path)
                    .await
                    .ok();
                if let Some(ref mut f) = file {
                    let c_off = pos - chunk_start(idx);
                    if c_off == 0 {
                        let _ = f.write_all(&chunk).await;
                    } else {
                        let _ = f.seek(SeekFrom::Start(c_off)).await;
                        let _ = f.write_all(&chunk).await;
                    }
                }
                let end = pos + chunk.len() as u64 - 1;
                add_range(&state, pos, end).await;
                pos = end + 1;
                write_offset = pos;
                if pos >= total {
                    return;
                }
            }
            tokio::time::sleep(Duration::from_millis(RECONNECT_DELAY_MS)).await;
        }
    })
}

async fn serve_root(
    State(state): State<Arc<SharedState>>,
    req: Request,
) -> Result<Response, StatusCode> {
    let method = req.method();
    let headers = req.headers();
    let meta = state.meta.read().await.clone();
    let Some(meta) = meta else {
        return Err(StatusCode::SERVICE_UNAVAILABLE);
    };
    let total = meta.length;
    let range_hdr = headers
        .get(header::RANGE)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| parse_range(s, total));
    let (start, end, status) = if let Some((s, e)) = range_hdr {
        (s, e, StatusCode::PARTIAL_CONTENT)
    } else {
        (0, total.saturating_sub(1), StatusCode::OK)
    };
    state
        .current_read_offset
        .store(start, Ordering::Relaxed);
    if *method == axum::http::Method::HEAD {
        return Response::builder()
            .status(status)
            .header(header::CONTENT_TYPE, &meta.content_type)
            .header(header::ACCEPT_RANGES, "bytes")
            .header(header::CONTENT_LENGTH, (end - start + 1).to_string())
            .header("Content-Range", format!("bytes {start}-{end}/{total}"))
            .body(Body::empty())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }
    wait_for_byte(&state, start).await;
    let mut body = Vec::with_capacity((end - start + 1).min(256 * 1024) as usize);
    let mut pos = start;
    while pos <= end {
        if !has_byte(&state, pos).await {
            wait_for_byte(&state, pos).await;
        }
        let idx = chunk_index(pos);
        let path = chunk_path(&state, idx);
        let c_start = chunk_start(idx);
        let off = pos - c_start;
        let mut file = fs::File::open(&path).await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        file.seek(SeekFrom::Start(off))
            .await
            .map_err(|_| StatusCode::BAD_GATEWAY)?;
        let max_in_chunk = (chunk_expected_size(state.as_ref(), idx).await as u64).saturating_sub(off);
        let want = (end - pos + 1).min(max_in_chunk).min(256 * 1024);
        let mut buf = vec![0u8; want as usize];
        let n = file
            .read(&mut buf)
            .await
            .map_err(|_| StatusCode::BAD_GATEWAY)?;
        body.extend_from_slice(&buf[..n]);
        pos += n as u64;
    }
    Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, &meta.content_type)
        .header(header::ACCEPT_RANGES, "bytes")
        .header(header::CONTENT_LENGTH, body.len().to_string())
        .header("Content-Range", format!("bytes {start}-{end}/{total}"))
        .body(Body::from(body))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

fn parse_range(hdr: &str, total: u64) -> Option<(u64, u64)> {
    let s = hdr.strip_prefix("bytes=")?;
    let (a, b) = s.split_once('-')?;
    let start: u64 = a.parse().ok()?;
    let end = if b.is_empty() {
        total.saturating_sub(1)
    } else {
        b.parse().ok()?
    };
    if start > end || start >= total {
        return None;
    }
    Some((start, end.min(total - 1)))
}

