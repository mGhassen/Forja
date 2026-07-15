use std::collections::HashMap;
use std::sync::mpsc;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use anime::request_json;
use serde_json::json;

pub const PRIMARY_BASE_URL: &str = "https://kisskh.co";
pub const MIRROR_BASE_URLS: &[&str] = &[
    "https://kisskh.co",
    "https://kisskh.nl",
    "https://kisskh.ovh",
    "https://kisskh.la",
    "https://kisskh.do",
];
const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
const CACHE_TTL: Duration = Duration::from_secs(600);
const MIRROR_PROBE_TIMEOUT: Duration = Duration::from_secs(6);

struct CacheEntry {
    body: String,
    expires: Instant,
}

static HTTP_CACHE: OnceLock<Mutex<HashMap<String, CacheEntry>>> = OnceLock::new();
static ACTIVE_BASE: OnceLock<Mutex<Option<String>>> = OnceLock::new();
static SELECT_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

fn cache() -> &'static Mutex<HashMap<String, CacheEntry>> {
    HTTP_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn active_base() -> &'static Mutex<Option<String>> {
    ACTIVE_BASE.get_or_init(|| Mutex::new(None))
}

fn select_lock() -> &'static Mutex<()> {
    SELECT_LOCK.get_or_init(|| Mutex::new(()))
}

fn default_headers(base: &str) -> HashMap<String, String> {
    let mut headers = HashMap::new();
    headers.insert("User-Agent".to_string(), USER_AGENT.to_string());
    headers.insert(
        "Accept".to_string(),
        "application/json,text/plain,*/*".to_string(),
    );
    headers.insert("Referer".to_string(), format!("{base}/"));
    headers.insert("Origin".to_string(), base.to_string());
    headers
}

fn is_transient_status(status: u16) -> bool {
    matches!(status, 429 | 502 | 503 | 504)
}

fn fetch(base: &str, url: &str, timeout_secs: u64, max_attempts: u32) -> Result<String, String> {
    let headers_json =
        serde_json::to_string(&default_headers(base)).unwrap_or_else(|_| "{}".to_string());
    let mut last_error = String::from("GET failed");

    for attempt in 0..max_attempts {
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
            "timeout_secs": timeout_secs,
            "max_retries": 0,
        });
        let raw = request_json(&req.to_string());
        let decoded: serde_json::Value =
            serde_json::from_str(&raw).unwrap_or_else(|_| json!({ "error": raw }));
        if let Some(err) = decoded.get("error").and_then(|v| v.as_str()) {
            last_error = err.to_string();
            if attempt + 1 < max_attempts {
                continue;
            }
            return Err(last_error);
        }
        let status = decoded.get("status").and_then(|v| v.as_u64()).unwrap_or(0) as u16;
        let body = decoded
            .get("body")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if status < 400 {
            return Ok(body);
        }
        last_error = format!("GET {url} → {status}");
        if is_transient_status(status) && attempt + 1 < max_attempts {
            continue;
        }
        return Err(last_error);
    }
    Err(last_error)
}

fn cached(url: &str) -> Option<String> {
    let guard = cache().lock().ok()?;
    let entry = guard.get(url)?;
    (Instant::now() < entry.expires).then(|| entry.body.clone())
}

fn store_cached(url: &str, body: &str) {
    if let Ok(mut guard) = cache().lock() {
        guard.insert(
            url.to_string(),
            CacheEntry {
                body: body.to_string(),
                expires: Instant::now() + CACHE_TTL,
            },
        );
    }
}

fn set_active_base(base: &str) {
    if let Ok(mut guard) = active_base().lock() {
        *guard = Some(base.to_string());
    }
}

pub fn activate_base_url(base: &str) -> Result<String, String> {
    let normalized = base.trim().trim_end_matches('/');
    if !MIRROR_BASE_URLS.contains(&normalized) {
        return Err(format!("Unsupported KissKh mirror: {normalized}"));
    }
    set_active_base(normalized);
    Ok(normalized.to_string())
}

pub fn current_base_url() -> String {
    active_base()
        .lock()
        .ok()
        .and_then(|guard| guard.clone())
        .unwrap_or_else(|| PRIMARY_BASE_URL.to_string())
}

fn domain_order() -> Vec<String> {
    let mut out = vec![current_base_url()];
    for base in MIRROR_BASE_URLS {
        if !out.iter().any(|item| item == base) {
            out.push((*base).to_string());
        }
    }
    out
}

fn is_compatible_probe_body(body: &str) -> bool {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(body) else {
        return false;
    };
    let Some(first) = value.as_array().and_then(|items| items.first()) else {
        return false;
    };
    first.get("id").and_then(|id| id.as_i64()).is_some()
        && first
            .get("title")
            .and_then(|title| title.as_str())
            .is_some_and(|title| !title.trim().is_empty())
}

fn is_json_body(body: &str) -> bool {
    serde_json::from_str::<serde_json::Value>(body).is_ok()
}

fn probe_base(base: &str) -> bool {
    let url = format!("{base}/api/DramaList/Show");
    fetch(base, &url, 5, 1)
        .map(|body| is_compatible_probe_body(&body))
        .unwrap_or(false)
}

/// Race API-compatible mirrors and keep the first valid response as the sticky
/// base. Only the five domains verified to expose the same Angular API and IDs
/// are candidates; similarly named WordPress clones are deliberately excluded.
pub fn select_base_url() -> Result<String, String> {
    if let Ok(guard) = active_base().lock() {
        if let Some(base) = guard.as_ref() {
            return Ok(base.clone());
        }
    }

    let _selection = select_lock()
        .lock()
        .map_err(|_| "KissKh mirror selector lock poisoned".to_string())?;
    if let Ok(guard) = active_base().lock() {
        if let Some(base) = guard.as_ref() {
            return Ok(base.clone());
        }
    }

    let (sender, receiver) = mpsc::channel();
    for &base in MIRROR_BASE_URLS {
        let sender = sender.clone();
        std::thread::spawn(move || {
            if probe_base(base) {
                let _ = sender.send(base.to_string());
            }
        });
    }
    drop(sender);

    let selected = receiver
        .recv_timeout(MIRROR_PROBE_TIMEOUT)
        .map_err(|_| "No compatible KissKh mirror responded".to_string())?;
    set_active_base(&selected);
    Ok(selected)
}

/// Fetch a KissKh API path with sticky-domain failover. A failed active mirror
/// is followed by every other verified mirror; the first successful request
/// becomes active for catalog calls and the host WebView extractor.
pub fn get_api(path: &str, use_cache: bool) -> Result<String, String> {
    let _ = select_base_url()?;
    let normalized = if path.starts_with('/') {
        path.to_string()
    } else {
        format!("/{path}")
    };
    let mut errors = Vec::new();

    for base in domain_order() {
        let url = format!("{base}/api{normalized}");
        if use_cache {
            if let Some(body) = cached(&url) {
                set_active_base(&base);
                return Ok(body);
            }
        }

        match fetch(&base, &url, 15, 3) {
            Ok(body) if is_json_body(&body) => {
                set_active_base(&base);
                if use_cache {
                    store_cached(&url, &body);
                }
                return Ok(body);
            }
            Ok(_) => errors.push(format!("{base}: API returned non-JSON content")),
            Err(error) => errors.push(format!("{base}: {error}")),
        }
    }

    Err(format!("KissKh mirrors failed: {}", errors.join(" | ")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_base_urls() {
        assert_eq!(PRIMARY_BASE_URL, "https://kisskh.co");
        assert_eq!(MIRROR_BASE_URLS.len(), 5);
        assert!(MIRROR_BASE_URLS.contains(&"https://kisskh.nl"));
        assert!(!MIRROR_BASE_URLS.contains(&"https://kisskh.buzz"));
    }

    #[test]
    fn validates_compatible_probe_shape() {
        assert!(is_compatible_probe_body(
            r#"[{"id":13228,"title":"Backrooms (2026)"}]"#
        ));
        assert!(!is_compatible_probe_body("<!doctype html>"));
        assert!(!is_compatible_probe_body(r#"[{"title":"Missing id"}]"#));
    }

    #[test]
    fn activation_rejects_unverified_domains() {
        assert!(activate_base_url("https://kisskh.ovh/").is_ok());
        assert!(activate_base_url("https://kisskh.buzz").is_err());
    }
}
