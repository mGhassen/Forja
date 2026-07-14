use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

use base64::Engine;
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::runtime::Runtime;

const OAUTH_UA: &str = "Forja/1.3.6 (by /u/ForjaApp)";
const SCRAPE_UA: &str = "Mozilla/5.0 (Linux; Android 11; Forja) \
    AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36";

const OAUTH_CLIENT_IDS: &[&str] = &[
    "ohXpoqrZYub1kg",
    "NOe2iKrPPzwscA",
    "JrPdG8Z6dkWNxA",
];

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("iptv reddit tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("iptv reddit http client")
});

struct OAuthCache {
    token: Option<String>,
    expiry: Option<Instant>,
    client_idx: usize,
}

static OAUTH_CACHE: LazyLock<Mutex<OAuthCache>> = LazyLock::new(|| {
    Mutex::new(OAuthCache {
        token: None,
        expiry: None,
        client_idx: 0,
    })
});

#[derive(Debug, Clone, Deserialize)]
pub struct RedditCatalogRequest {
    pub action: String,
    #[serde(default)]
    pub sub: Option<String>,
    #[serde(default)]
    pub after: Option<String>,
    #[serde(default)]
    pub url: Option<String>,
}

pub fn catalog_json(request_json: &str) -> String {
    let req: RedditCatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    match req.action.as_str() {
        "oauth_listing" => {
            let sub = req.sub.unwrap_or_default();
            if sub.is_empty() {
                return json!({ "error": "sub required" }).to_string();
            }
            fetch_oauth_listing(&sub, req.after.as_deref())
        }
        "rss_listing" => {
            let sub = req.sub.unwrap_or_default();
            if sub.is_empty() {
                return json!({ "error": "sub required" }).to_string();
            }
            fetch_rss_listing(&sub, req.after.as_deref())
        }
        "fetch_paste" => {
            let url = req.url.unwrap_or_default();
            if url.is_empty() {
                return json!({ "error": "url required" }).to_string();
            }
            fetch_paste_text(&url)
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

fn http_get(url: &str, headers: &HashMap<String, String>, timeout_secs: u64) -> Option<String> {
    RUNTIME
        .block_on(async {
            utils::engine_cancel::with_cancel(async {
                let timeout = Duration::from_secs(timeout_secs.max(1));
                let mut req = CLIENT.get(url).timeout(timeout);
                for (k, v) in headers {
                    req = req.header(k.as_str(), v.as_str());
                }
                let resp = req.send().await.map_err(|e| e.to_string())?;
                if !resp.status().is_success() {
                    return Err(format!("http {}", resp.status()));
                }
                resp.text().await.map_err(|e| e.to_string())
            })
            .await
        })
        .ok()
}

fn http_post(
    url: &str,
    headers: &HashMap<String, String>,
    body: &str,
    timeout_secs: u64,
) -> Option<String> {
    RUNTIME
        .block_on(async {
            utils::engine_cancel::with_cancel(async {
                let timeout = Duration::from_secs(timeout_secs.max(1));
                let mut req = CLIENT.post(url).timeout(timeout).body(body.to_string());
                for (k, v) in headers {
                    req = req.header(k.as_str(), v.as_str());
                }
                let resp = req.send().await.map_err(|e| e.to_string())?;
                if !resp.status().is_success() {
                    return Err(format!("http {}", resp.status()));
                }
                resp.text().await.map_err(|e| e.to_string())
            })
            .await
        })
        .ok()
}

fn get_oauth_token() -> Option<String> {
    {
        let cache = OAUTH_CACHE.lock().ok()?;
        if let (Some(token), Some(expiry)) = (&cache.token, cache.expiry) {
            if Instant::now() < expiry {
                return Some(token.clone());
            }
        }
    }

    let start_idx = OAUTH_CACHE.lock().ok()?.client_idx;

    for i in 0..OAUTH_CLIENT_IDS.len() {
        let idx = (start_idx + i) % OAUTH_CLIENT_IDS.len();
        let client_id = OAUTH_CLIENT_IDS[idx];
        let auth = base64::engine::general_purpose::STANDARD.encode(format!("{client_id}:"));
        let mut headers = HashMap::new();
        headers.insert("User-Agent".into(), OAUTH_UA.into());
        headers.insert("Authorization".into(), format!("Basic {auth}"));
        headers.insert(
            "Content-Type".into(),
            "application/x-www-form-urlencoded".into(),
        );
        let body = "grant_type=https%3A%2F%2Foauth.reddit.com%2Fgrants%2Finstalled_client&device_id=DO_NOT_TRACK_THIS_DEVICE";
        let resp_body = http_post(
            "https://www.reddit.com/api/v1/access_token",
            &headers,
            body,
            8,
        )?;
        let parsed: Value = serde_json::from_str(&resp_body).ok()?;
        let token = parsed.get("access_token")?.as_str()?.to_string();
        if token.is_empty() {
            continue;
        }
        let expires_in = parsed
            .get("expires_in")
            .and_then(|v| v.as_u64())
            .unwrap_or(3600);
        let expiry = Instant::now() + Duration::from_secs(expires_in.saturating_sub(60));
        if let Ok(mut cache) = OAUTH_CACHE.lock() {
            cache.token = Some(token.clone());
            cache.expiry = Some(expiry);
            cache.client_idx = idx;
        }
        return Some(token);
    }

    if let Ok(mut cache) = OAUTH_CACHE.lock() {
        cache.client_idx = (cache.client_idx + 1) % OAUTH_CLIENT_IDS.len();
        cache.token = None;
        cache.expiry = None;
    }
    None
}

fn fetch_oauth_listing(sub: &str, after: Option<&str>) -> String {
    let token = match get_oauth_token() {
        Some(t) => t,
        None => return json!({ "error": "oauth token unavailable" }).to_string(),
    };

    let mut url = format!(
        "https://oauth.reddit.com/r/{sub}/new?limit=100&sort=new&raw_json=1"
    );
    if let Some(a) = after.filter(|s| !s.is_empty()) {
        url.push_str("&after=");
        url.push_str(a);
    }

    let mut headers = HashMap::new();
    headers.insert("User-Agent".into(), OAUTH_UA.into());
    headers.insert("Authorization".into(), format!("Bearer {token}"));

    match http_get(&url, &headers, 12) {
        Some(body) => {
            let trimmed = body.trim_start();
            if trimmed.starts_with('{') || trimmed.starts_with('[') {
                json!({ "body": body }).to_string()
            } else {
                invalidate_oauth_token();
                json!({ "error": "invalid oauth response" }).to_string()
            }
        }
        None => {
            invalidate_oauth_token();
            json!({ "error": "oauth fetch failed" }).to_string()
        }
    }
}

fn fetch_rss_listing(sub: &str, after: Option<&str>) -> String {
    let mut url = format!("https://www.reddit.com/r/{sub}/new/.rss?limit=25");
    if let Some(a) = after.filter(|s| !s.is_empty()) {
        url.push_str("&after=");
        url.push_str(a);
    }

    let headers = HashMap::from([
        ("User-Agent".into(), OAUTH_UA.into()),
        (
            "Accept".into(),
            "application/atom+xml, application/xml, */*".into(),
        ),
    ]);

    match http_get(&url, &headers, 15) {
        Some(body) if body.contains("<entry>") => json!({ "body": body }).to_string(),
        _ => json!({ "error": "rss fetch failed" }).to_string(),
    }
}

fn fetch_paste_text(url: &str) -> String {
    if url.contains("paste.sh/") && url.contains('#') {
        let hash_idx = match url.find('#') {
            Some(i) => i,
            None => return json!({ "error": "invalid paste.sh url" }).to_string(),
        };
        let base_url = &url[..hash_idx];
        let fetch_url = format!("{base_url}.txt");
        let headers = HashMap::from([("User-Agent".into(), SCRAPE_UA.into())]);
        let raw = match http_get(&fetch_url, &headers, 15) {
            Some(b) => b,
            None => return json!({ "error": "paste fetch failed" }).to_string(),
        };
        let decrypted = crate::pastesh::decrypt_from_paste_response(url, &raw).unwrap_or_default();
        if decrypted.is_empty() {
            return json!({ "error": "paste decrypt failed" }).to_string();
        }
        return json!({ "body": decrypted }).to_string();
    }

    let fetch_url = rewrite_paste_url(url);
    let headers = HashMap::from([
        ("User-Agent".into(), SCRAPE_UA.into()),
        (
            "Accept".into(),
            "text/html,application/json,*/*".into(),
        ),
    ]);
    match http_get(&fetch_url, &headers, 15) {
        Some(body) if !body.is_empty() => json!({ "body": body }).to_string(),
        _ => json!({ "error": "paste fetch failed" }).to_string(),
    }
}

fn rewrite_paste_url(url: &str) -> String {
    if url.contains("pastebin.com/") && !url.contains("/raw/") {
        if let Some(id) = last_path_segment(url) {
            return format!("https://pastebin.com/raw/{id}");
        }
    }
    if url.contains("pastes.dev/") {
        if let Some(id) = last_path_segment(url) {
            return format!("https://api.pastes.dev/{id}");
        }
    }
    if url.contains("rentry.co/") && !url.contains("/raw") {
        if let Some(id) = last_path_segment(url) {
            return format!("https://rentry.co/{id}/raw");
        }
    }
    url.to_string()
}

fn last_path_segment(url: &str) -> Option<String> {
    let mut s = url;
    if let Some(h) = s.find('#') {
        s = &s[..h];
    }
    if let Some(q) = s.find('?') {
        s = &s[..q];
    }
    let slash = s.rfind('/')?;
    let seg = s[slash + 1..].trim();
    if seg.is_empty() {
        None
    } else {
        Some(seg.to_string())
    }
}

fn invalidate_oauth_token() {
    if let Ok(mut cache) = OAUTH_CACHE.lock() {
        cache.token = None;
        cache.expiry = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = catalog_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn oauth_listing_requires_sub() {
        let raw = catalog_json(r#"{"action":"oauth_listing"}"#);
        assert!(raw.contains("sub required"));
    }

    #[test]
    fn rewrite_pastebin_url() {
        let out = rewrite_paste_url("https://pastebin.com/abc123");
        assert_eq!(out, "https://pastebin.com/raw/abc123");
    }

    #[test]
    fn rewrite_rentry_url() {
        let out = rewrite_paste_url("https://rentry.co/foo");
        assert_eq!(out, "https://rentry.co/foo/raw");
    }

    #[test]
    fn last_path_segment_strips_hash() {
        assert_eq!(
            last_path_segment("https://paste.sh/id#key"),
            Some("id".into())
        );
    }
}
