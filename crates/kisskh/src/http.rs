use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use anime::request_json;
use serde_json::json;

const BASE_URL: &str = "https://kisskh.co";
const USER_AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
const CACHE_TTL: Duration = Duration::from_secs(600);

struct CacheEntry {
    body: String,
    expires: Instant,
}

static HTTP_CACHE: OnceLock<Mutex<HashMap<String, CacheEntry>>> = OnceLock::new();

fn cache() -> &'static Mutex<HashMap<String, CacheEntry>> {
    HTTP_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn default_headers() -> HashMap<String, String> {
    let mut headers = HashMap::new();
    headers.insert("User-Agent".to_string(), USER_AGENT.to_string());
    headers.insert(
        "Accept".to_string(),
        "application/json,text/plain,*/*".to_string(),
    );
    headers.insert("Referer".to_string(), format!("{BASE_URL}/"));
    headers
}

fn is_transient_status(status: u16) -> bool {
    matches!(status, 429 | 502 | 503 | 504)
}

fn fetch_once(url: &str) -> Result<String, String> {
    const MAX_ATTEMPTS: u32 = 3;
    let headers_json =
        serde_json::to_string(&default_headers()).unwrap_or_else(|_| "{}".to_string());
    let mut last_error = String::from("GET failed");

    for attempt in 0..MAX_ATTEMPTS {
        if utils::engine_cancel::is_shutdown_requested() {
            return Err(utils::engine_cancel::cancelled_message());
        }
        if attempt > 0 {
            std::thread::sleep(Duration::from_millis(400 * attempt as u64));
        }
        let req = json!({
            "url": url,
            "method": "GET",
            "headers_json": headers_json,
            "timeout_secs": 15,
            "max_retries": 0,
        });
        let raw = request_json(&req.to_string());
        let decoded: serde_json::Value =
            serde_json::from_str(&raw).unwrap_or_else(|_| json!({ "error": raw }));
        if let Some(err) = decoded.get("error").and_then(|v| v.as_str()) {
            last_error = err.to_string();
            if attempt + 1 < MAX_ATTEMPTS {
                continue;
            }
            return Err(last_error);
        }
        let status = decoded
            .get("status")
            .and_then(|v| v.as_u64())
            .unwrap_or(0) as u16;
        let body = decoded
            .get("body")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if status < 400 {
            return Ok(body);
        }
        last_error = format!("GET {url} → {status}");
        if is_transient_status(status) && attempt + 1 < MAX_ATTEMPTS {
            continue;
        }
        return Err(last_error);
    }
    Err(last_error)
}

pub fn get(url: &str, use_cache: bool) -> Result<String, String> {
    if use_cache {
        if let Ok(guard) = cache().lock() {
            if let Some(entry) = guard.get(url) {
                if Instant::now() < entry.expires {
                    return Ok(entry.body.clone());
                }
            }
        }
    }

    let body = fetch_once(url)?;

    if use_cache {
        if let Ok(mut guard) = cache().lock() {
            guard.insert(
                url.to_string(),
                CacheEntry {
                    body: body.clone(),
                    expires: Instant::now() + CACHE_TTL,
                },
            );
        }
    }

    Ok(body)
}

pub fn api_base() -> String {
    format!("{BASE_URL}/api")
}

pub fn base_url() -> &'static str {
    BASE_URL
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_base_urls() {
        assert_eq!(base_url(), "https://kisskh.co");
        assert!(api_base().ends_with("/api"));
    }
}
