use std::collections::HashMap;
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
    "https://kisskh.is",
    "https://kisskh.id",
];

fn mirror_list() -> Vec<String> {
    utils::provider_runtime::kisskh_mirrors().unwrap_or_else(|| {
        MIRROR_BASE_URLS.iter().map(|s| (*s).to_string()).collect()
    })
}

fn is_known_mirror(base: &str) -> bool {
    mirror_list().iter().any(|m| m == base)
}
const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
const CACHE_TTL: Duration = Duration::from_secs(600);

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
    if !is_known_mirror(normalized) {
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
        .unwrap_or_else(|| {
            mirror_list()
                .into_iter()
                .next()
                .unwrap_or_else(|| PRIMARY_BASE_URL.to_string())
        })
}

fn domain_order() -> Vec<String> {
    let mut out = vec![current_base_url()];
    for base in mirror_list() {
        if !out.iter().any(|item| item == &base) {
            out.push(base);
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
    // Short timeout — health gate only; never nest threads that call
    // anime::request_json (shared Tokio Runtime::block_on deadlocks).
    fetch(base, &url, 3, 1)
        .map(|body| is_compatible_probe_body(&body))
        .unwrap_or(false)
}

/// Probe one verified mirror on the calling thread.
pub fn probe_one(base: &str) -> Result<(String, bool), String> {
    let normalized = base.trim().trim_end_matches('/');
    if !is_known_mirror(normalized) {
        return Err(format!("Unsupported KissKh mirror: {normalized}"));
    }
    Ok((normalized.to_string(), probe_base(normalized)))
}

/// Probe every verified mirror on the calling thread (no OS-thread fan-out).
/// Parallelism belongs in Dart (`Future.wait` of `probe_one`) so each job
/// owns a single `block_on` on an engine worker isolate.
pub fn probe_mirrors() -> Vec<(String, bool)> {
    mirror_list()
        .into_iter()
        .map(|base| {
            let ok = probe_base(&base);
            (base, ok)
        })
        .collect()
}

/// Pick the first healthy mirror as sticky. Sequential on purpose — spawning
/// threads that each `block_on` the shared anime Tokio runtime deadlocks and
/// freezes the loading overlay on CHECKING forever.
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

    for base in mirror_list() {
        if probe_base(&base) {
            set_active_base(&base);
            return Ok(base);
        }
    }
    Err("No compatible KissKh mirror responded".to_string())
}

/// Fetch signed Episode + Subtitle JSON for one episode (native kkey, no WebView).
/// With no forced base, Episode GETs use sticky-domain failover like catalog
/// [`get_api`] — a single dead/geo-blocked mirror must not fail the resolve.
pub fn resolve_episode_stream(
    episode_id: i32,
    forced_base: Option<&str>,
) -> Result<(String, serde_json::Value, Vec<serde_json::Value>), String> {
    if episode_id <= 0 {
        return Err("episode_id required".to_string());
    }
    let forced = if let Some(raw) = forced_base {
        let normalized = raw.trim().trim_end_matches('/');
        if normalized.is_empty() {
            None
        } else {
            Some(activate_base_url(normalized)?)
        }
    } else {
        None
    };

    let vid_key = crate::generate_kkey(episode_id, crate::KkeyKind::Video);
    let ep_path = format!(
        "/DramaList/Episode/{episode_id}.png?err=false&ts=&time=&kkey={vid_key}"
    );
    // Do not cache stream payloads — CDN URLs go stale.
    let ep_body = if let Some(ref base) = forced {
        get_api_on_base(base, &ep_path)?
    } else {
        get_api(&ep_path, false)?
    };
    let base = forced
        .clone()
        .unwrap_or_else(current_base_url);
    let episode: serde_json::Value = serde_json::from_str(&ep_body)
        .map_err(|e| format!("Episode JSON parse failed: {e}"))?;

    let mut subs = Vec::new();
    let sub_key = crate::generate_kkey(episode_id, crate::KkeyKind::Subtitle);
    let sub_path = format!("/Sub/{episode_id}?kkey={sub_key}");
    if let Ok(sub_body) = get_api_on_base(&base, &sub_path) {
        if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&sub_body) {
            if let Some(arr) = parsed.as_array() {
                for item in arr {
                    if let Some(obj) = item.as_object() {
                        let src = obj
                            .get("src")
                            .or_else(|| obj.get("url"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .trim();
                        if src.is_empty() {
                            continue;
                        }
                        let label = obj
                            .get("label")
                            .or_else(|| obj.get("language"))
                            .or_else(|| obj.get("land"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("Unknown");
                        subs.push(json!({
                            "id": src,
                            "url": src,
                            "language": label,
                            "display": format!("{label} - kisskh"),
                            "sourceName": "kisskh",
                        }));
                    }
                }
            }
        }
    }

    Ok((base, episode, subs))
}

fn get_api_on_base(base: &str, path: &str) -> Result<String, String> {
    let normalized = if path.starts_with('/') {
        path.to_string()
    } else {
        format!("/{path}")
    };
    let url = format!("{base}/api{normalized}");
    match fetch(base, &url, 15, 2) {
        Ok(body) if is_json_body(&body) => Ok(body),
        Ok(_) => Err(format!("{base}: API returned non-JSON content")),
        Err(error) => Err(format!("{base}: {error}")),
    }
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
        assert_eq!(MIRROR_BASE_URLS.len(), 7);
        assert!(MIRROR_BASE_URLS.contains(&"https://kisskh.nl"));
        assert!(MIRROR_BASE_URLS.contains(&"https://kisskh.is"));
        assert!(MIRROR_BASE_URLS.contains(&"https://kisskh.id"));
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
        assert!(activate_base_url("https://kisskh.is/").is_ok());
        assert!(activate_base_url("https://kisskh.id").is_ok());
        assert!(activate_base_url("https://kisskh.buzz").is_err());
    }

    #[test]
    fn resolve_stream_live_episode() {
        // Clear sticky so failover can leave a geo-blocked .co.
        if let Ok(mut guard) = active_base().lock() {
            *guard = None;
        }
        let (base, episode, _subs) =
            resolve_episode_stream(171699, None).expect("resolve");
        assert!(
            MIRROR_BASE_URLS.contains(&base.as_str()),
            "unexpected base {base}"
        );
        let video = episode
            .get("Video")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert!(
            video.contains("http"),
            "expected playable Video from {base}, got {episode}"
        );
        // Subs are best-effort in resolve (empty/missing Sub JSON is not a
        // stream failure — mirrors often omit tracks or 451 the Sub path).
    }
}
