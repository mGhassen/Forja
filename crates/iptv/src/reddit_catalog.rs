use std::collections::{BTreeMap, HashMap, HashSet};
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

use base64::Engine;
use regex::Regex;
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::runtime::Runtime;

use crate::portal_extract::{extract_portals, Portal};

const OAUTH_UA: &str = "Forja/1.3.6 (by /u/ForjaApp)";
const SCRAPE_UA: &str = "Mozilla/5.0 (Linux; Android 11; Forja) \
    AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36";

const OAUTH_CLIENT_IDS: &[&str] = &[
    "ohXpoqrZYub1kg",
    "NOe2iKrPPzwscA",
    "JrPdG8Z6dkWNxA",
];

const CATALOG_SUBS: &[&str] = &["IPTV_ZONENEW", "FreeIPTV", "iptvguru", "IPTVfree"];

const PASTE_DOMAINS: &[&str] = &[
    "paste.sh",
    "pastebin.com",
    "justpaste.it",
    "controlc.com",
    "pastes.dev",
    "text.is",
    "rentry.co",
];

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("iptv reddit tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("iptv reddit http client")
});

static B64_HTTP: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"aHR0c[a-zA-Z0-9+/=]{10,}").expect("b64 regex"));

static RAW_PASTE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)https?://(?:paste\.sh|pastebin\.com|justpaste\.it|controlc\.com|pastes\.dev|text\.is|rentry\.co)/[a-zA-Z0-9#_=-]+",
    )
    .expect("raw paste regex")
});

static ENTRY_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<entry>(.*?)</entry>").expect("entry regex"));
static TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<title[^>]*>(.*?)</title>").expect("title regex"));
static CONTENT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?s)<content[^>]*>(.*?)</content>").expect("content regex"));
static ID_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"<id>(t3_[^<]+)</id>").expect("id regex"));
static BLOCK_TAGS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<(?:p|br|div|li|h\d)[^>]*>").expect("block tags"));
static ANY_TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<[^>]+>").expect("any tag"));
static MULTI_WS: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").expect("ws"));

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
    #[serde(default)]
    pub text: Option<String>,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub max_results: Option<usize>,
}

pub fn catalog_json(request_json: &str) -> String {
    let req: RedditCatalogRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    match req.action.as_str() {
        "scrape_page" => scrape_page(req.after.as_deref(), req.max_results.unwrap_or(50)),
        "extract_portals" => {
            let text = req.text.unwrap_or_default();
            let source = req.source.unwrap_or_else(|| "Catalog".to_string());
            let portals = extract_portals(&text, &source);
            json!({ "portals": portals }).to_string()
        }
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
            match fetch_paste_body(&url) {
                Some(body) => json!({ "body": body }).to_string(),
                None => json!({ "error": "paste fetch failed" }).to_string(),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[derive(Debug, Clone, Default)]
pub struct CatalogCursor {
    pub sub_idx: usize,
    pub after: Option<String>,
}

/// Cursor formats (parity with Dart `parseRedditCatalogCursor`):
///   `reddit:<subIdx>:<token>` — current
///   `reddit:<token>`          — legacy (sub 0)
///   `<token>`                 — legacy bare token (sub 0)
pub fn parse_reddit_catalog_cursor(after: Option<&str>) -> CatalogCursor {
    let Some(after) = after.filter(|s| !s.is_empty()) else {
        return CatalogCursor::default();
    };
    if let Some(rest) = after.strip_prefix("reddit:") {
        if rest.is_empty() {
            return CatalogCursor::default();
        }
        if let Some((idx_s, token)) = rest.split_once(':') {
            let sub_idx = idx_s.parse::<usize>().unwrap_or(0);
            let page_after = if token.is_empty() || token == "null" {
                None
            } else {
                Some(token.to_string())
            };
            return CatalogCursor {
                sub_idx,
                after: page_after,
            };
        }
        let page_after = if rest == "null" {
            None
        } else {
            Some(rest.to_string())
        };
        return CatalogCursor {
            sub_idx: 0,
            after: page_after,
        };
    }
    let page_after = if after == "null" {
        None
    } else {
        Some(after.to_string())
    };
    CatalogCursor {
        sub_idx: 0,
        after: page_after,
    }
}

fn scrape_page(after: Option<&str>, max_results: usize) -> String {
    let max_results = max_results.max(1);
    let cursor = parse_reddit_catalog_cursor(after);
    let mut sub_idx = cursor.sub_idx;
    if sub_idx >= CATALOG_SUBS.len() {
        sub_idx = 0;
    }
    let current_sub = CATALOG_SUBS[sub_idx];
    let reddit_after = cursor.after;

    let mut out: BTreeMap<String, Portal> = BTreeMap::new();

    if let Some(body) = fetch_oauth_listing_body(current_sub, reddit_after.as_deref()) {
        if let Ok(root) = serde_json::from_str::<Value>(&body) {
            if let Some(data) = root.get("data") {
                let posts = data
                    .get("children")
                    .and_then(|c| c.as_array())
                    .cloned()
                    .unwrap_or_default();
                let next_after_raw = data
                    .get("after")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());
                let has_more = next_after_raw
                    .as_ref()
                    .map(|s| !s.is_empty() && s != "null")
                    .unwrap_or(false);

                let next_after = if has_more {
                    Some(format!(
                        "reddit:{}:{}",
                        sub_idx,
                        next_after_raw.unwrap_or_default()
                    ))
                } else if sub_idx + 1 < CATALOG_SUBS.len() {
                    Some(format!("reddit:{}:", sub_idx + 1))
                } else {
                    None
                };

                process_oauth_posts(&posts, &mut out, max_results);
                process_oauth_deep_links(&posts, &mut out, max_results);

                return json!({
                    "portals": out.into_values().collect::<Vec<_>>(),
                    "next_after": next_after,
                })
                .to_string();
            }
        }
    }

    // RSS fallback
    let Some(rss_body) = fetch_rss_listing_body(current_sub, reddit_after.as_deref()) else {
        let next_after = if sub_idx + 1 < CATALOG_SUBS.len() {
            Some(format!("reddit:{}:", sub_idx + 1))
        } else {
            None
        };
        return json!({
            "portals": [],
            "next_after": next_after,
        })
        .to_string();
    };

    let entries: Vec<_> = ENTRY_RE
        .captures_iter(&rss_body)
        .filter_map(|c| c.get(1).map(|m| m.as_str().to_string()))
        .collect();
    let post_ids: Vec<_> = ID_RE
        .captures_iter(&rss_body)
        .filter_map(|c| c.get(1).map(|m| m.as_str().to_string()))
        .collect();
    let last_post_id = post_ids.last().cloned();
    let next_after = if last_post_id.is_some() && entries.len() >= 20 {
        Some(format!(
            "reddit:{}:{}",
            sub_idx,
            last_post_id.unwrap_or_default()
        ))
    } else if sub_idx + 1 < CATALOG_SUBS.len() {
        Some(format!("reddit:{}:", sub_idx + 1))
    } else {
        None
    };

    for entry_text in entries {
        if out.len() >= max_results {
            break;
        }
        let title = TITLE_RE
            .captures(&entry_text)
            .and_then(|c| c.get(1))
            .map(|m| decode_xml_entities(m.as_str()))
            .unwrap_or_default();
        let raw_content = CONTENT_RE
            .captures(&entry_text)
            .and_then(|c| c.get(1))
            .map(|m| decode_xml_entities(m.as_str()))
            .unwrap_or_default();
        let stripped = BLOCK_TAGS.replace_all(&raw_content, "\n");
        let stripped = ANY_TAG.replace_all(&stripped, " ");
        let stripped = MULTI_WS.replace_all(&stripped, " ");
        let body = format!("{title} {}", stripped.trim()).trim().to_string();
        add_extracted(&mut out, &body, "Catalog", max_results);
    }

    json!({
        "portals": out.into_values().collect::<Vec<_>>(),
        "next_after": next_after,
    })
    .to_string()
}

fn process_oauth_posts(posts: &[Value], out: &mut BTreeMap<String, Portal>, max_results: usize) {
    for post in posts {
        if out.len() >= max_results {
            break;
        }
        let Some(pdata) = post.get("data") else {
            continue;
        };
        let title = pdata
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let selftext = pdata
            .get("selftext")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let body = format!("{title} {selftext}").trim().to_string();
        add_extracted(out, &body, "Catalog", max_results);
    }
}

fn process_oauth_deep_links(
    posts: &[Value],
    out: &mut BTreeMap<String, Portal>,
    max_results: usize,
) {
    for post in posts {
        if out.len() >= max_results {
            break;
        }
        let Some(pdata) = post.get("data") else {
            continue;
        };
        let title = pdata
            .get("title")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let selftext = pdata
            .get("selftext")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let body = format!("{title} {selftext}").trim().to_string();

        let mut deep_links: Vec<String> = Vec::new();
        for m in B64_HTTP.find_iter(&body) {
            if let Ok(decoded_bytes) = base64::engine::general_purpose::STANDARD.decode(m.as_str())
            {
                let decoded = String::from_utf8_lossy(&decoded_bytes);
                if decoded.starts_with("http") && is_paste_site(&decoded) {
                    deep_links.push(decoded.into_owned());
                } else if !decoded.starts_with("http") && decoded.contains(':') {
                    add_extracted(out, &decoded, "Catalog (decoded)", max_results);
                }
            }
        }
        for m in RAW_PASTE.find_iter(&body) {
            deep_links.push(m.as_str().to_string());
        }

        let mut seen = HashSet::new();
        let unique: Vec<_> = deep_links
            .into_iter()
            .filter(|u| seen.insert(u.clone()))
            .take(4)
            .collect();

        for dl in unique {
            if out.len() >= max_results {
                break;
            }
            if let Some(text) = fetch_paste_body(&dl) {
                if !text.is_empty() {
                    add_extracted(out, &text, "Catalog (deep)", max_results);
                }
            }
        }
    }
}

fn add_extracted(
    out: &mut BTreeMap<String, Portal>,
    text: &str,
    source: &str,
    max_results: usize,
) {
    for p in extract_portals(text, source) {
        if out.len() >= max_results {
            break;
        }
        out.entry(p.key()).or_insert(p);
    }
}

fn is_paste_site(url: &str) -> bool {
    PASTE_DOMAINS.iter().any(|d| url.contains(d))
}

fn decode_xml_entities(s: &str) -> String {
    s.replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&#32;", " ")
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
    match fetch_oauth_listing_body(sub, after) {
        Some(body) => json!({ "body": body }).to_string(),
        None => json!({ "error": "oauth fetch failed" }).to_string(),
    }
}

fn fetch_oauth_listing_body(sub: &str, after: Option<&str>) -> Option<String> {
    let token = get_oauth_token()?;

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
                Some(body)
            } else {
                invalidate_oauth_token();
                None
            }
        }
        None => {
            invalidate_oauth_token();
            None
        }
    }
}

fn fetch_rss_listing(sub: &str, after: Option<&str>) -> String {
    match fetch_rss_listing_body(sub, after) {
        Some(body) => json!({ "body": body }).to_string(),
        None => json!({ "error": "rss fetch failed" }).to_string(),
    }
}

fn fetch_rss_listing_body(sub: &str, after: Option<&str>) -> Option<String> {
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
        Some(body) if body.contains("<entry>") => Some(body),
        _ => None,
    }
}

fn fetch_paste_body(url: &str) -> Option<String> {
    if url.contains("paste.sh/") && url.contains('#') {
        let hash_idx = url.find('#')?;
        let base_url = &url[..hash_idx];
        let fetch_url = format!("{base_url}.txt");
        let headers = HashMap::from([("User-Agent".into(), SCRAPE_UA.into())]);
        let raw = http_get(&fetch_url, &headers, 15)?;
        let decrypted = crate::pastesh::decrypt_from_paste_response(url, &raw).unwrap_or_default();
        if decrypted.is_empty() {
            return None;
        }
        return Some(decrypted);
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
        Some(body) if !body.is_empty() => Some(body),
        _ => None,
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
    fn extract_portals_action() {
        let raw = catalog_json(
            r#"{"action":"extract_portals","text":"http://x.example/get.php?username=abc123&password=def456","source":"t"}"#,
        );
        let v: Value = serde_json::from_str(&raw).unwrap();
        let portals = v["portals"].as_array().unwrap();
        assert_eq!(portals.len(), 1);
        assert_eq!(portals[0]["username"], "abc123");
    }

    #[test]
    fn parse_cursor_advances_subreddit() {
        let c = parse_reddit_catalog_cursor(Some("reddit:1:"));
        assert_eq!(c.sub_idx, 1);
        assert!(c.after.is_none());
    }

    #[test]
    fn parse_cursor_keeps_token() {
        let c = parse_reddit_catalog_cursor(Some("reddit:0:t3_abc123"));
        assert_eq!(c.sub_idx, 0);
        assert_eq!(c.after.as_deref(), Some("t3_abc123"));
    }

    #[test]
    fn parse_cursor_legacy() {
        let c = parse_reddit_catalog_cursor(Some("reddit:t3_legacy"));
        assert_eq!(c.sub_idx, 0);
        assert_eq!(c.after.as_deref(), Some("t3_legacy"));
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
