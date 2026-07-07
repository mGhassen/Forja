use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use regex::Regex;
use serde_json::{json, Value};

use crate::http::{block_on, client};
use crate::types::AudioStream;

const FALLBACK_API_KEY: &str = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";
const CONFIG_TTL: Duration = Duration::from_secs(3 * 3600);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(15);
const DESKTOP_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
    (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36";

static VIDEO_ID_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""videoId"\s*:\s*"([a-zA-Z0-9_-]{11})""#).expect("video id re"));
static API_KEY_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""INNERTUBE_API_KEY":"([^"]+)""#).expect("api key re"));
static VISITOR_DATA_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#""VISITOR_DATA":"([^"]+)""#).expect("visitor re"));

static CONFIG: LazyLock<Mutex<Option<CachedConfig>>> = LazyLock::new(|| Mutex::new(None));
static VIDEO_ID_CACHE: LazyLock<Mutex<HashMap<String, CachedVideoId>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static STREAM_CACHE: LazyLock<Mutex<HashMap<String, CachedStream>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

struct YtClient {
    key: &'static str,
    id: &'static str,
    version: &'static str,
    user_agent: &'static str,
    context: Value,
    requires_visitor_data: bool,
}

fn clients() -> &'static [YtClient] {
    static CLIENTS: LazyLock<Vec<YtClient>> = LazyLock::new(|| {
        vec![
            YtClient {
                key: "android_vr",
                id: "28",
                version: "1.56.21",
                user_agent: "com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1) gzip",
                context: json!({
                    "clientName": "ANDROID_VR",
                    "clientVersion": "1.56.21",
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "osName": "Android",
                    "osVersion": "12",
                    "platform": "MOBILE",
                    "androidSdkVersion": 32,
                    "hl": "en",
                    "gl": "US"
                }),
                requires_visitor_data: true,
            },
            YtClient {
                key: "android",
                id: "3",
                version: "20.10.35",
                user_agent: "com.google.android.youtube/20.10.35 (Linux; U; Android 14; en_US) gzip",
                context: json!({
                    "clientName": "ANDROID",
                    "clientVersion": "20.10.35",
                    "osName": "Android",
                    "osVersion": "14",
                    "platform": "MOBILE",
                    "androidSdkVersion": 34,
                    "hl": "en",
                    "gl": "US"
                }),
                requires_visitor_data: false,
            },
            YtClient {
                key: "ios",
                id: "5",
                version: "20.10.1",
                user_agent: "com.google.ios.youtube/20.10.1 (iPhone16,2; U; CPU iOS 17_4 like Mac OS X)",
                context: json!({
                    "clientName": "IOS",
                    "clientVersion": "20.10.1",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone",
                    "osVersion": "17.4.0.21E219",
                    "platform": "MOBILE",
                    "hl": "en",
                    "gl": "US"
                }),
                requires_visitor_data: false,
            },
        ]
    });
    CLIENTS.as_slice()
}

#[derive(Clone)]
struct CachedConfig {
    api_key: String,
    visitor_data: Option<String>,
    fetched_at: Instant,
    forced: bool,
}

impl CachedConfig {
    fn is_expired(&self) -> bool {
        self.fetched_at.elapsed() >= CONFIG_TTL
    }
}

struct CachedVideoId {
    video_id: String,
    cached_at: Instant,
}

impl CachedVideoId {
    fn is_expired(&self) -> bool {
        self.cached_at.elapsed() >= Duration::from_secs(12 * 3600)
    }
}

struct CachedStream {
    url: String,
    expires_at: Option<SystemTime>,
    cached_at: Instant,
}

impl CachedStream {
    fn is_expired(&self) -> bool {
        if let Some(exp) = self.expires_at {
            return SystemTime::now()
                >= exp.checked_sub(Duration::from_secs(60)).unwrap_or(exp);
        }
        self.cached_at.elapsed() >= Duration::from_secs(4 * 3600)
    }
}

pub fn search_video_id(title: &str, artist: &str) -> Result<Option<String>, String> {
    block_on(search_video_id_async(title, artist))
}

pub fn audio_url(video_id: &str) -> Result<String, String> {
    block_on(audio_url_async(video_id))
}

pub fn audio_streams(video_id: &str) -> Result<Vec<AudioStream>, String> {
    block_on(audio_streams_async(video_id))
}

async fn search_video_id_async(title: &str, artist: &str) -> Result<Option<String>, String> {
    let query = format!("{title} {artist} lyrics");
    {
        let cache = VIDEO_ID_CACHE.lock().map_err(|e| e.to_string())?;
        if let Some(hit) = cache.get(&query) {
            if !hit.is_expired() {
                return Ok(Some(hit.video_id.clone()));
            }
        }
    }

    let encoded = urlencoding::encode(&query);
    let url = format!("https://www.youtube.com/results?search_query={encoded}");
    let http = client(REQUEST_TIMEOUT)?;
    let resp = http
        .get(&url)
        .header("User-Agent", DESKTOP_UA)
        .header("Accept-Language", "en-US,en;q=0.9")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("search HTTP {}", resp.status()));
    }
    let body = resp.text().await.map_err(|e| e.to_string())?;
    let id = VIDEO_ID_RE
        .captures(&body)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string());
    if let Some(ref video_id) = id {
        if let Ok(mut cache) = VIDEO_ID_CACHE.lock() {
            cache.insert(
                query,
                CachedVideoId {
                    video_id: video_id.clone(),
                    cached_at: Instant::now(),
                },
            );
        }
    }
    Ok(id)
}

async fn audio_url_async(video_id: &str) -> Result<String, String> {
    {
        let cache = STREAM_CACHE.lock().map_err(|e| e.to_string())?;
        if let Some(hit) = cache.get(video_id) {
            if !hit.is_expired() {
                return Ok(hit.url.clone());
            }
        }
    }

    let config = ensure_config(false).await?;
    if let Some(url) = try_clients(video_id, &config).await? {
        return Ok(url);
    }
    if !config.forced {
        let config = ensure_config(true).await?;
        if let Some(url) = try_clients(video_id, &config).await? {
            return Ok(url);
        }
    }
    Err("no audio stream found".into())
}

async fn audio_streams_async(video_id: &str) -> Result<Vec<AudioStream>, String> {
    let config = ensure_config(false).await?;
    if let Some(streams) = collect_streams(video_id, &config).await? {
        if !streams.is_empty() {
            return Ok(streams);
        }
    }
    if !config.forced {
        let config = ensure_config(true).await?;
        if let Some(streams) = collect_streams(video_id, &config).await? {
            if !streams.is_empty() {
                return Ok(streams);
            }
        }
    }
    Err("no audio streams found".into())
}

async fn try_clients(video_id: &str, config: &CachedConfig) -> Result<Option<String>, String> {
    for client_def in clients() {
        if client_def.requires_visitor_data
            && config.visitor_data.as_deref().unwrap_or("").is_empty()
        {
            continue;
        }
        let player = match fetch_player(config, video_id, client_def).await {
            Ok(v) => v,
            Err(_) => continue,
        };
        let status = map_val(&player, "playabilityStatus")
            .and_then(|m| str_field(m, "status"));
        if status.as_deref() == Some("LOGIN_REQUIRED") {
            continue;
        }
        let streaming_data = map_val(&player, "streamingData");
        let Some(streaming_data) = streaming_data else {
            continue;
        };
        if let Some(best) = pick_best_audio(&streaming_data) {
            if let Ok(mut cache) = STREAM_CACHE.lock() {
                cache.insert(
                    video_id.to_string(),
                    CachedStream {
                        url: best.url.clone(),
                        expires_at: best.expires_at,
                        cached_at: Instant::now(),
                    },
                );
            }
            return Ok(Some(best.url));
        }
    }
    Ok(None)
}

async fn collect_streams(
    video_id: &str,
    config: &CachedConfig,
) -> Result<Option<Vec<AudioStream>>, String> {
    let mut all = Vec::new();
    for client_def in clients() {
        if client_def.requires_visitor_data
            && config.visitor_data.as_deref().unwrap_or("").is_empty()
        {
            continue;
        }
        let player = match fetch_player(config, video_id, client_def).await {
            Ok(v) => v,
            Err(_) => continue,
        };
        let streaming_data = map_val(&player, "streamingData");
        let Some(streaming_data) = streaming_data else {
            continue;
        };
        all.extend(list_audio_streams(&streaming_data));
        if !all.is_empty() {
            break;
        }
    }
    if all.is_empty() {
        return Ok(None);
    }
    all.sort_by(|a, b| b.bitrate.partial_cmp(&a.bitrate).unwrap_or(std::cmp::Ordering::Equal));
    Ok(Some(all))
}

struct AudioCandidate {
    url: String,
    bitrate: f64,
    expires_at: Option<SystemTime>,
    mime_type: Option<String>,
}

fn pick_best_audio(streaming_data: &Value) -> Option<AudioCandidate> {
    list_audio_candidates(streaming_data)
        .into_iter()
        .max_by(|a, b| a.bitrate.partial_cmp(&b.bitrate).unwrap_or(std::cmp::Ordering::Equal))
}

fn list_audio_streams(streaming_data: &Value) -> Vec<AudioStream> {
    list_audio_candidates(streaming_data)
        .into_iter()
        .map(|c| AudioStream {
            url: c.url,
            bitrate: c.bitrate,
            mime_type: c.mime_type,
        })
        .collect()
}

fn list_audio_candidates(streaming_data: &Value) -> Vec<AudioCandidate> {
    let mut out = Vec::new();
    for f in list_of_maps(streaming_data.get("adaptiveFormats")) {
        let mime = str_field(&f, "mimeType").unwrap_or_default();
        if !mime.contains("audio/") {
            continue;
        }
        let Some(url) = str_field(&f, "url") else {
            continue;
        };
        if url.is_empty() {
            continue;
        }
        let bitrate = num_field(&f, "bitrate")
            .or_else(|| num_field(&f, "averageBitrate"))
            .unwrap_or(0.0);
        out.push(AudioCandidate {
            url: url.clone(),
            bitrate,
            expires_at: expires_at(&url),
            mime_type: Some(mime),
        });
    }
    if !out.is_empty() {
        return out;
    }
    for f in list_of_maps(streaming_data.get("formats")) {
        let Some(url) = str_field(&f, "url") else {
            continue;
        };
        if url.is_empty() {
            continue;
        }
        let bitrate = num_field(&f, "bitrate")
            .or_else(|| num_field(&f, "averageBitrate"))
            .unwrap_or(0.0);
        out.push(AudioCandidate {
            url: url.clone(),
            bitrate,
            expires_at: expires_at(&url),
            mime_type: str_field(&f, "mimeType"),
        });
    }
    out
}

fn expires_at(url: &str) -> Option<SystemTime> {
    let parsed = url::Url::parse(url).ok()?;
    let expire = parsed.query_pairs().find(|(k, _)| k == "expire")?.1;
    let secs: u64 = expire.parse().ok()?;
    Some(UNIX_EPOCH + Duration::from_secs(secs))
}

async fn ensure_config(force_refresh: bool) -> Result<CachedConfig, String> {
    if !force_refresh {
        if let Ok(guard) = CONFIG.lock() {
            if let Some(cfg) = guard.as_ref() {
                if !cfg.is_expired() {
                    return Ok(cfg.clone());
                }
            }
        }
    } else if let Ok(mut guard) = CONFIG.lock() {
        *guard = None;
    }

    fetch_config(force_refresh).await
}

async fn fetch_config(forced: bool) -> Result<CachedConfig, String> {
    let http = client(REQUEST_TIMEOUT)?;
    let resp = http
        .get("https://www.youtube.com/watch?v=dQw4w9WgXcQ&hl=en")
        .header("User-Agent", DESKTOP_UA)
        .header("Accept-Language", "en-US,en;q=0.9")
        .send()
        .await;
    let cfg = match resp {
        Ok(r) if r.status().is_success() => {
            let body = r.text().await.unwrap_or_default();
            let api_key = API_KEY_RE
                .captures(&body)
                .and_then(|c| c.get(1))
                .map(|m| m.as_str().to_string())
                .unwrap_or_else(|| FALLBACK_API_KEY.to_string());
            let visitor_data = VISITOR_DATA_RE
                .captures(&body)
                .and_then(|c| c.get(1))
                .map(|m| m.as_str().to_string());
            CachedConfig {
                api_key,
                visitor_data,
                fetched_at: Instant::now(),
                forced,
            }
        }
        _ => CachedConfig {
            api_key: FALLBACK_API_KEY.to_string(),
            visitor_data: None,
            fetched_at: Instant::now(),
            forced,
        },
    };
    if let Ok(mut guard) = CONFIG.lock() {
        *guard = Some(cfg.clone());
    }
    Ok(cfg)
}

async fn fetch_player(
    config: &CachedConfig,
    video_id: &str,
    client_def: &YtClient,
) -> Result<Value, String> {
    let uri = format!(
        "https://www.youtube.com/youtubei/v1/player?key={}",
        urlencoding::encode(&config.api_key)
    );
    let http = client(REQUEST_TIMEOUT)?;
    let mut req = http
        .post(&uri)
        .header("Content-Type", "application/json")
        .header("Accept-Language", "en-US,en;q=0.9")
        .header("Origin", "https://www.youtube.com")
        .header("User-Agent", client_def.user_agent)
        .header("X-YouTube-Client-Name", client_def.id)
        .header("X-YouTube-Client-Version", client_def.version);
    if let Some(visitor) = config.visitor_data.as_ref() {
        if !visitor.is_empty() {
            req = req.header("X-Goog-Visitor-Id", visitor);
        }
    }
    let body = json!({
        "videoId": video_id,
        "contentCheckOk": true,
        "racyCheckOk": true,
        "context": { "client": client_def.context },
        "playbackContext": {
            "contentPlaybackContext": { "html5Preference": "HTML5_PREF_WANTS" }
        }
    });
    let resp = req.json(&body).send().await.map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("player API {} failed ({})", client_def.key, resp.status()));
    }
    resp.json::<Value>().await.map_err(|e| e.to_string())
}

fn map_val<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    value.get(key)
}

fn list_of_maps(value: Option<&Value>) -> Vec<&Value> {
    value
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().collect())
        .unwrap_or_default()
}

fn str_field(obj: &Value, key: &str) -> Option<String> {
    obj.get(key).and_then(|v| match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    })
}

fn num_field(obj: &Value, key: &str) -> Option<f64> {
    obj.get(key).and_then(|v| match v {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expires_at_parses_query() {
        let url = "https://rr1---sn.example.googlevideo.com/videoplayback?expire=1700000000";
        assert!(expires_at(url).is_some());
    }
}
