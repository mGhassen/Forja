//! Mega.nz embed decrypt loopback proxy (AES-128-CTR).

use aes::cipher::{KeyIvInit, StreamCipher, StreamCipherSeek};
use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, Method, StatusCode},
    response::Response,
    routing::get,
    Router,
};
use base64::Engine;
use futures_util::StreamExt;
use regex::Regex;
use serde::Serialize;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, LazyLock};
use tokio::sync::RwLock;

type Aes128Ctr = ctr::Ctr128BE<aes::Aes128>;

static EMBED_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)mega\.nz/(?:embed|file)/([^!#?/]+)[!#]([A-Za-z0-9_-]+)")
        .expect("embed re")
});
static LEGACY_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)mega\.nz/#!([^!#?/]+)!([A-Za-z0-9_-]+)").expect("legacy re")
});
static API_SEQ: AtomicU64 = AtomicU64::new(0);

#[derive(Clone)]
struct MegaFile {
    dl_url: String,
    size: u64,
    aes_key: [u8; 16],
    nonce: [u8; 8],
}

#[derive(Clone)]
struct AppState {
    files: Arc<RwLock<HashMap<String, MegaFile>>>,
    client: reqwest::Client,
}

struct MegaServer {
    port: u16,
    _shutdown: tokio::sync::oneshot::Sender<()>,
}

static SERVER: LazyLock<tokio::sync::Mutex<Option<MegaServer>>> =
    LazyLock::new(|| tokio::sync::Mutex::new(None));
static FILES: LazyLock<Arc<RwLock<HashMap<String, MegaFile>>>> =
    LazyLock::new(|| Arc::new(RwLock::new(HashMap::new())));

#[derive(Debug, Serialize)]
pub struct MegaResolveResponse {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

pub async fn resolve(embed_url: &str) -> MegaResolveResponse {
    match resolve_inner(embed_url).await {
        Ok((url, size)) => MegaResolveResponse {
            url: Some(url),
            size: Some(size),
            error: None,
        },
        Err(e) => MegaResolveResponse {
            url: None,
            size: None,
            error: Some(e),
        },
    }
}

async fn resolve_inner(embed_url: &str) -> Result<(String, u64), String> {
    let (file_id, key_bytes) =
        parse_embed(embed_url).ok_or_else(|| "could not parse embed".to_string())?;
    let (aes_key, nonce) = derive_keys(&key_bytes)?;

    let api = mega_api(&file_id).await?;
    let size = api
        .get("s")
        .and_then(|v| v.as_u64())
        .filter(|&s| s > 0)
        .ok_or_else(|| "api missing size".to_string())?;
    let dl_url = api
        .get("g")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "api missing download url".to_string())?
        .to_string();

    let port = ensure_server().await?;
    let token = format!(
        "{}_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_micros())
            .unwrap_or(0),
        API_SEQ.fetch_add(1, Ordering::Relaxed)
    );
    FILES.write().await.insert(
        token.clone(),
        MegaFile {
            dl_url,
            size,
            aes_key,
            nonce,
        },
    );
    Ok((format!("http://127.0.0.1:{port}/v/{token}.mp4"), size))
}

async fn ensure_server() -> Result<u16, String> {
    let mut guard = SERVER.lock().await;
    if let Some(s) = guard.as_ref() {
        return Ok(s.port);
    }

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| e.to_string())?;

    let state = AppState {
        files: FILES.clone(),
        client,
    };
    let app = Router::new()
        .route("/v/{token}", get(serve).head(serve))
        .with_state(state);

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
    *guard = Some(MegaServer { port, _shutdown: tx });
    Ok(port)
}

async fn serve(
    State(state): State<AppState>,
    Path(token): Path<String>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let token = token.split('.').next().unwrap_or(&token).to_string();
    let file = {
        let files = state.files.read().await;
        files.get(&token).cloned()
    };
    let Some(file) = file else {
        return Err(StatusCode::NOT_FOUND);
    };

    let (start, end, has_range) = match parse_range(&headers, file.size) {
        Ok(v) => v,
        Err(_) => {
            return Response::builder()
                .status(StatusCode::RANGE_NOT_SATISFIABLE)
                .header(header::CONTENT_RANGE, format!("bytes */{}", file.size))
                .body(Body::empty())
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
    };
    if start > end {
        return Response::builder()
            .status(StatusCode::RANGE_NOT_SATISFIABLE)
            .header(header::CONTENT_RANGE, format!("bytes */{}", file.size))
            .body(Body::empty())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }
    let length = end - start + 1;

    let mut builder = Response::builder()
        .status(if has_range {
            StatusCode::PARTIAL_CONTENT
        } else {
            StatusCode::OK
        })
        .header(header::CONTENT_TYPE, "video/mp4")
        .header(header::ACCEPT_RANGES, "bytes")
        .header(header::CONTENT_LENGTH, length.to_string());
    if has_range {
        builder = builder.header(
            header::CONTENT_RANGE,
            format!("bytes {start}-{end}/{}", file.size),
        );
    }

    if method == Method::HEAD {
        return builder
            .body(Body::empty())
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    let req = state
        .client
        .get(&file.dl_url)
        .header(header::RANGE, format!("bytes={start}-{end}"))
        .build()
        .map_err(|_| StatusCode::BAD_GATEWAY)?;
    let resp = state
        .client
        .execute(req)
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?;
    if !resp.status().is_success() {
        return Err(StatusCode::BAD_GATEWAY);
    }

    let mut cipher = build_cipher(&file.aes_key, &file.nonce, start);
    let stream = resp.bytes_stream().map(move |chunk| {
        chunk.map_err(std::io::Error::other).map(|bytes| {
            let mut out = bytes.to_vec();
            cipher.apply_keystream(&mut out);
            out
        })
    });

    builder
        .body(Body::from_stream(stream))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

fn parse_range(headers: &HeaderMap, size: u64) -> Result<(u64, u64, bool), ()> {
    let mut start = 0u64;
    let mut end = size.saturating_sub(1);
    let mut has_range = false;
    if let Some(range) = headers.get(header::RANGE).and_then(|v| v.to_str().ok()) {
        if let Some(rest) = range.strip_prefix("bytes=") {
            has_range = true;
            let parts: Vec<&str> = rest.splitn(2, '-').collect();
            if let Some(s) = parts.first().and_then(|p| p.parse().ok()) {
                start = s;
            }
            if parts.len() > 1 {
                if let Some(e) = parts[1].parse().ok() {
                    end = e;
                }
            }
        }
    }
    if start >= size {
        return Err(());
    }
    if end >= size {
        end = size - 1;
    }
    Ok((start, end, has_range))
}

fn build_cipher(aes_key: &[u8; 16], nonce: &[u8; 8], byte_start: u64) -> Aes128Ctr {
    let block_index = byte_start / 16;
    let leading_skip = (byte_start % 16) as usize;
    let mut iv = [0u8; 16];
    iv[..8].copy_from_slice(nonce);
    let mut c = block_index;
    for i in (8..16).rev() {
        iv[i] = (c & 0xff) as u8;
        c >>= 8;
    }
    let mut cipher = Aes128Ctr::new(aes_key.into(), &iv.into());
    cipher.seek(block_index);
    if leading_skip > 0 {
        let mut skip = vec![0u8; leading_skip];
        cipher.apply_keystream(&mut skip);
    }
    cipher
}

async fn mega_api(file_id: &str) -> Result<serde_json::Map<String, serde_json::Value>, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(12))
        .build()
        .map_err(|e| e.to_string())?;
    let id = API_SEQ.fetch_add(1, Ordering::Relaxed);
    let url = format!("https://g.api.mega.co.nz/cs?id={id}");
    let body = serde_json::json!([{"a": "g", "g": 1, "ssl": 1, "p": file_id}]);
    let raw = client
        .post(&url)
        .header(header::CONTENT_TYPE, "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .text()
        .await
        .map_err(|e| e.to_string())?;
    let parsed: serde_json::Value =
        serde_json::from_str(&raw).map_err(|e| format!("api json: {e}"))?;
    let Some(first) = parsed.as_array().and_then(|a| a.first()) else {
        return Err("api empty response".into());
    };
    if let Some(obj) = first.as_object() {
        return Ok(obj.clone());
    }
    Err(format!("api error: {first}"))
}

pub fn parse_embed(url: &str) -> Option<(String, Vec<u8>)> {
    let caps = EMBED_RE
        .captures(url)
        .or_else(|| LEGACY_RE.captures(url))?;
    let id = caps.get(1)?.as_str().to_string();
    let key_b64 = caps.get(2)?.as_str();
    let key_bytes = b64url_decode(key_b64)?;
    if key_bytes.len() != 32 {
        return None;
    }
    Some((id, key_bytes))
}

fn derive_keys(key_bytes: &[u8]) -> Result<([u8; 16], [u8; 8]), String> {
    if key_bytes.len() != 32 {
        return Err("file key must be 32 bytes".into());
    }
    let mut aes_key = [0u8; 16];
    for i in 0..16 {
        aes_key[i] = key_bytes[i] ^ key_bytes[i + 16];
    }
    let mut nonce = [0u8; 8];
    nonce.copy_from_slice(&key_bytes[16..24]);
    Ok((aes_key, nonce))
}

fn b64url_decode(s: &str) -> Option<Vec<u8>> {
    let mut x = s.replace('-', "+").replace('_', "/").replace(',', "");
    while x.len() % 4 != 0 {
        x.push('=');
    }
    base64::engine::general_purpose::STANDARD.decode(x).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_embed_url() {
        let key_b64 = base64::engine::general_purpose::STANDARD
            .encode([0u8; 32])
            .trim_end_matches('=')
            .replace('+', "-")
            .replace('/', "_");
        let url = format!("https://mega.nz/embed/abc123!{key_b64}");
        let (id, key) = parse_embed(&url).unwrap();
        assert_eq!(id, "abc123");
        assert_eq!(key.len(), 32);
    }

    #[test]
    fn parses_file_hash_url() {
        let key_b64 = base64::engine::general_purpose::STANDARD
            .encode([1u8; 32])
            .trim_end_matches('=')
            .replace('+', "-")
            .replace('/', "_");
        let url = format!("https://mega.nz/file/xyz#{key_b64}");
        assert!(parse_embed(&url).is_some());
    }

    #[test]
    fn rejects_short_key() {
        assert!(parse_embed("https://mega.nz/embed/id!c2hvcnQ").is_none());
    }

    #[test]
    fn derive_keys_xor_halves() {
        let key = (0u8..32).collect::<Vec<_>>();
        let (aes, nonce) = derive_keys(&key).unwrap();
        assert_eq!(aes[0], 0 ^ 16);
        assert_eq!(nonce, [16, 17, 18, 19, 20, 21, 22, 23]);
    }

    #[test]
    fn ctr_round_trip_at_offset() {
        let key = [0u8; 16];
        let nonce = [1u8; 8];
        let plain = b"hello mega proxy!!";
        let mut enc = build_cipher(&key, &nonce, 0);
        let mut cipher_bytes = plain.to_vec();
        enc.apply_keystream(&mut cipher_bytes);

        let mut dec = build_cipher(&key, &nonce, 0);
        let mut out = cipher_bytes.clone();
        dec.apply_keystream(&mut out);
        assert_eq!(&out[..plain.len()], plain);
    }
}
