use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use serde_json::{json, Value};
use tokio::runtime::Runtime;

const STREAMED_BASE: &str = "https://streamed.pk";
const PPV_ORIGIN: &str = "https://ppv.is";
const PPV_STREAM_APIS: &[&str] = &[
    "https://api.ppv.st/api/streams",
    "https://api.ppv.cx/api/streams",
];
/// Official MutStreams mirrors ([mutgo.link](https://mutgo.link/)). Only hosts
/// that return JSON for `/api/streams` — `mutstreams.art` / `.su` currently
/// serve HTML and are omitted.
const MUT_BASES: &[&str] = &[
    "https://mut.st",
    "https://mutstreams.st",
    "https://mutstreams.ch",
    "https://mutstreams.pk",
];

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("live-matches tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("live-matches http client")
});

fn ppv_headers() -> HashMap<String, String> {
    HashMap::from([
        (
            "User-Agent".into(),
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".into(),
        ),
        ("Accept".into(), "application/json".into()),
        ("Origin".into(), PPV_ORIGIN.into()),
        ("Referer".into(), "https://ppv.is/".into()),
    ])
}

fn streamed_headers() -> HashMap<String, String> {
    HashMap::from([
        (
            "User-Agent".into(),
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".into(),
        ),
        ("Accept".into(), "application/json".into()),
        ("Origin".into(), STREAMED_BASE.into()),
        ("Referer".into(), "https://streamed.pk/".into()),
    ])
}

pub(crate) fn ok_items(items: Vec<Value>) -> String {
    json!({ "items": items }).to_string()
}

pub(crate) fn block_on<F: std::future::Future>(fut: F) -> F::Output {
    RUNTIME.block_on(fut)
}

pub(crate) async fn http_get_async(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
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
    .ok()
}

pub(crate) fn http_get(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
    RUNTIME.block_on(http_get_async(url, headers, timeout_secs))
}

/// Alias for callers that want a clearer name (JSON body as text).
pub(crate) fn http_get_json(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
    http_get(url, headers, timeout_secs)
}

pub fn streamed_sports() -> String {
    let url = format!("{STREAMED_BASE}/api/sports");
    let body = match http_get(&url, &streamed_headers(), 12) {
        Some(b) => b,
        None => return ok_items(vec![]),
    };
    let list = match serde_json::from_str::<Vec<Value>>(&body) {
        Ok(v) => v,
        Err(_) => return ok_items(vec![]),
    };
    let items: Vec<Value> = list
        .into_iter()
        .filter_map(|s| {
            let id = s.get("id")?.to_string().trim_matches('"').to_string();
            let name = s.get("name")?.to_string().trim_matches('"').to_string();
            if id.is_empty() || name.is_empty() {
                return None;
            }
            Some(json!({ "id": id, "name": name }))
        })
        .collect();
    ok_items(items)
}

fn streamed_matches_list(path: &str) -> Vec<Value> {
    let url = format!("{STREAMED_BASE}{path}");
    let body = match http_get(&url, &streamed_headers(), 15) {
        Some(b) => b,
        None => return vec![],
    };
    serde_json::from_str::<Vec<Value>>(&body).unwrap_or_default()
}

/// Match id used for dedupe — Streamed sometimes lists the same event under
/// different ids on `/live` vs `/all` (e.g. `ppv-tour-…` vs `tour-…-2447760`).
fn streamed_match_id(m: &Value) -> Option<String> {
    m.get("id")
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
}

/// Merge `/api/matches/all` (schedule) with `/api/matches/live` (currently
/// airing). The website Popular Live row uses `/live`; several events (ACA,
/// some PPV mirrors) appear there only and are missing from `/all`.
///
/// Live rows win on id collision and are tagged `airing: true` so the host
/// can show LIVE / allow play without guessing from start time alone.
pub fn streamed_matches() -> String {
    let all = streamed_matches_list("/api/matches/all");
    let live = streamed_matches_list("/api/matches/live");

    let mut by_id: HashMap<String, Value> = HashMap::new();
    for m in all {
        if let Some(id) = streamed_match_id(&m) {
            by_id.insert(id, m);
        }
    }
    for m in live {
        let Some(id) = streamed_match_id(&m) else {
            continue;
        };
        let mut row = m;
        if let Some(obj) = row.as_object_mut() {
            obj.insert("airing".into(), Value::Bool(true));
        }
        by_id.insert(id, row);
    }

    ok_items(by_id.into_values().collect())
}

pub fn streamed_streams(source: &str, id: &str) -> String {
    let url = format!("{STREAMED_BASE}/api/stream/{source}/{id}");
    let body = match http_get(&url, &streamed_headers(), 12) {
        Some(b) => b,
        None => return ok_items(vec![]),
    };
    let list = match serde_json::from_str::<Vec<Value>>(&body) {
        Ok(v) => v,
        Err(_) => return ok_items(vec![]),
    };
    let items: Vec<Value> = list
        .into_iter()
        .filter(|s| {
            s.get("embedUrl")
                .or_else(|| s.get("embed_url"))
                .and_then(|v| v.as_str())
                .is_some_and(|u| !u.is_empty())
        })
        .collect();
    ok_items(items)
}

pub fn damitv_streams() -> String {
    let headers = ppv_headers();
    for endpoint in PPV_STREAM_APIS {
        let body = match http_get(endpoint, &headers, 12) {
            Some(b) => b,
            None => continue,
        };
        let parsed: Value = match serde_json::from_str(&body) {
            Ok(v) => v,
            Err(_) => continue,
        };
        if parsed.get("success") != Some(&Value::Bool(true)) {
            continue;
        }
        let mut result = Vec::new();
        if let Some(categories) = parsed.get("streams").and_then(|v| v.as_array()) {
            for cat in categories {
                if let Some(streams) = cat.get("streams").and_then(|v| v.as_array()) {
                    for s in streams {
                        result.push(s.clone());
                    }
                }
            }
        }
        if !result.is_empty() {
            return ok_items(result);
        }
    }
    ok_items(vec![])
}


fn mut_headers(base: &str) -> HashMap<String, String> {
    let origin = base.trim_end_matches('/');
    HashMap::from([
        (
            "User-Agent".into(),
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".into(),
        ),
        ("Accept".into(), "application/json".into()),
        ("Origin".into(), origin.into()),
        ("Referer".into(), format!("{origin}/")),
    ])
}

/// Parse Mut time strings like `05:00 PM PST - (07/30/2026)`.
/// Site always labels PST; treat as UTC−8.
pub(crate) fn parse_mut_time(raw: &str) -> i64 {
    let raw = raw.trim();
    if raw.is_empty() {
        return 0;
    }
    let Some(open) = raw.rfind('(') else {
        return 0;
    };
    let Some(close) = raw[open..].find(')') else {
        return 0;
    };
    let date = raw[open + 1..open + close].trim();
    let parts: Vec<&str> = date.split('/').collect();
    if parts.len() != 3 {
        return 0;
    }
    let (Ok(month), Ok(day), Ok(year)) = (
        parts[0].parse::<u32>(),
        parts[1].parse::<u32>(),
        parts[2].parse::<i32>(),
    ) else {
        return 0;
    };

    let time_part = raw[..open]
        .split("PST")
        .next()
        .unwrap_or("")
        .trim()
        .trim_end_matches('-')
        .trim();
    let mut bits = time_part.split_whitespace();
    let Some(hm) = bits.next() else {
        return 0;
    };
    let ampm = bits.next().unwrap_or("AM").to_ascii_uppercase();
    let hm_parts: Vec<&str> = hm.split(':').collect();
    if hm_parts.len() != 2 {
        return 0;
    }
    let (Ok(mut hour), Ok(minute)) = (hm_parts[0].parse::<u32>(), hm_parts[1].parse::<u32>())
    else {
        return 0;
    };
    if ampm.starts_with('P') && hour < 12 {
        hour += 12;
    }
    if ampm.starts_with('A') && hour == 12 {
        hour = 0;
    }

    // Civil → unix via days since 1970-01-01 (UTC−8 for labeled PST).
    let Some(day_num) = civil_days(year, month, day) else {
        return 0;
    };
    let secs = (day_num as i64) * 86400 + (hour as i64) * 3600 + (minute as i64) * 60 + 8 * 3600;
    secs * 1000
}

fn civil_days(year: i32, month: u32, day: u32) -> Option<i64> {
    if !(1..=12).contains(&month) || day == 0 || day > 31 {
        return None;
    }
    // Howard Hinnant civil_from_days inverse (days since 1970-01-01).
    let y = if month <= 2 { year - 1 } else { year };
    let era = y.div_euclid(400);
    let yoe = (y - era * 400) as u32;
    let m = month as i64;
    let doy = (153 * (m + if m > 2 { -3 } else { 9 }) + 2) / 5 + day as i64 - 1;
    let doe = (yoe as i64) * 365 + (yoe as i64) / 4 - (yoe as i64) / 100 + doy;
    Some(era as i64 * 146097 + doe - 719468)
}

fn mut_stream_id(url: &str, title: &str) -> String {
    let slug = url
        .trim()
        .trim_start_matches('/')
        .strip_prefix("watch/")
        .unwrap_or(url.trim().trim_start_matches('/'));
    if !slug.is_empty() {
        return slug.to_string();
    }
    title
        .trim()
        .to_ascii_lowercase()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .trim_matches('-')
        .to_string()
}

fn flatten_mut_streams(body: &str) -> Option<Vec<Value>> {
    let categories: Vec<Value> = serde_json::from_str(body).ok()?;
    if categories.is_empty() {
        return None;
    }
    // HTML error pages parse as null/object, not a category array with streams.
    let first = categories.first()?;
    if first.get("streams").is_none() && first.get("title").is_none() {
        return None;
    }

    let mut result = Vec::new();
    for cat in categories {
        let streams = match cat.get("streams").and_then(|v| v.as_array()) {
            Some(s) => s,
            None => continue,
        };
        for s in streams {
            let title = s
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .trim()
                .to_string();
            if title.is_empty() {
                continue;
            }
            let url = s.get("url").and_then(|v| v.as_str()).unwrap_or("");
            let id = mut_stream_id(url, &title);
            if id.is_empty() {
                continue;
            }
            let category = s
                .get("groupId")
                .and_then(|v| v.as_str())
                .or_else(|| cat.get("title").and_then(|v| v.as_str()))
                .unwrap_or("other")
                .to_ascii_lowercase()
                .replace(' ', "-");
            let poster = s.get("image").and_then(|v| v.as_str()).unwrap_or("");
            let date_ms = parse_mut_time(s.get("time").and_then(|v| v.as_str()).unwrap_or(""));

            let mut source_refs = Vec::new();
            let mut inline_streams = Vec::new();
            if let Some(sources) = s.get("sources").and_then(|v| v.as_array()) {
                for src in sources {
                    let embed = src
                        .get("embedUrl")
                        .or_else(|| src.get("embed_url"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    if embed.is_empty() {
                        continue;
                    }
                    let source = src
                        .get("source")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    let sid = src
                        .get("id")
                        .map(|v| match v {
                            Value::String(s) => s.clone(),
                            other => other.to_string().trim_matches('"').to_string(),
                        })
                        .unwrap_or_default();
                    if source.is_empty() || sid.is_empty() {
                        continue;
                    }
                    source_refs.push(json!({ "source": source, "id": sid }));
                    inline_streams.push(json!({
                        "id": sid,
                        "streamNo": src.get("streamNo").cloned().unwrap_or(Value::from(0)),
                        "language": src.get("language").cloned().unwrap_or(Value::String(String::new())),
                        "hd": src.get("hd").cloned().unwrap_or(Value::Bool(false)),
                        "embedUrl": embed,
                        "source": source,
                        "viewers": src.get("viewers").cloned().unwrap_or(Value::from(0)),
                    }));
                }
            }

            let airing = !inline_streams.is_empty();
            result.push(json!({
                "id": id,
                "title": title,
                "category": category,
                "date": date_ms,
                "poster": poster,
                "popular": false,
                "airing": airing,
                "sources": source_refs,
                "streams": inline_streams,
                "catalog": "mut",
            }));
        }
    }
    if result.is_empty() {
        None
    } else {
        Some(result)
    }
}

/// MutStreams schedule + inline embed sources (`/api/streams`).
/// Tries official mirrors until one returns a parseable category list.
pub fn mut_matches() -> String {
    for base in MUT_BASES {
        let url = format!("{}/api/streams", base.trim_end_matches('/'));
        let body = match http_get(&url, &mut_headers(base), 15) {
            Some(b) => b,
            None => continue,
        };
        if let Some(items) = flatten_mut_streams(&body) {
            return ok_items(items);
        }
    }
    ok_items(vec![])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn streamed_sports_parses_list() {
        let body = r#"[{"id":"football","name":"Football"},{"id":"","name":"X"},{"name":"Y"}]"#;
        let list: Vec<Value> = serde_json::from_str(body).unwrap();
        let items: Vec<Value> = list
            .into_iter()
            .filter_map(|s| {
                let id = s.get("id")?.to_string().trim_matches('"').to_string();
                let name = s.get("name")?.to_string().trim_matches('"').to_string();
                if id.is_empty() || name.is_empty() {
                    return None;
                }
                Some(json!({ "id": id, "name": name }))
            })
            .collect();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0]["id"], "football");
    }

    #[test]
    fn streamed_matches_merge_tags_airing_and_keeps_all_only() {
        // Simulate merge: all has Open; live has ACA + Open (same id) → ACA
        // appears, Open is marked airing, all-only Nascar stays.
        let mut by_id: HashMap<String, Value> = HashMap::new();
        for m in [
            json!({"id":"open","title":"Open","category":"golf"}),
            json!({"id":"nascar","title":"Nascar","category":"motor-sports"}),
        ] {
            by_id.insert(m["id"].as_str().unwrap().into(), m);
        }
        for m in [json!({"id":"aca","title":"ACA","category":"other"}), json!({"id":"open","title":"Open Live","category":"golf"})]
        {
            let id = m["id"].as_str().unwrap().to_string();
            let mut row = m;
            row.as_object_mut()
                .unwrap()
                .insert("airing".into(), Value::Bool(true));
            by_id.insert(id, row);
        }
        assert_eq!(by_id.len(), 3);
        assert_eq!(by_id["aca"]["airing"], true);
        assert_eq!(by_id["open"]["airing"], true);
        assert_eq!(by_id["open"]["title"], "Open Live");
        assert!(by_id["nascar"].get("airing").is_none());
    }

    #[test]
    fn streamed_streams_filters_empty_embed() {
        let body = r#"[{"embedUrl":"http://x"},{"embedUrl":""},{"id":1}]"#;
        let list: Vec<Value> = serde_json::from_str(body).unwrap();
        let items: Vec<Value> = list
            .into_iter()
            .filter(|s| {
                s.get("embedUrl")
                    .and_then(|v| v.as_str())
                    .is_some_and(|u| !u.is_empty())
            })
            .collect();
        assert_eq!(items.len(), 1);
    }


    #[test]
    fn parse_mut_time_pst_date() {
        let ms = parse_mut_time("05:00 PM PST - (07/30/2026)");
        assert!(ms > 0);
        // 2026-07-30 17:00 PST = 2026-07-31 01:00 UTC
        assert_eq!(ms, 1_785_459_600_000);
    }

    #[test]
    fn flatten_mut_streams_inline_embeds() {
        let body = r#"[{
            "title":"Basketball",
            "streams":[{
                "title":"Team A vs Team B",
                "image":"https://example/icon.svg",
                "time":"05:00 PM PST - (07/30/2026)",
                "url":"/watch/team-a-vs-team-b",
                "groupId":"basketball",
                "sources":[{
                    "id":"ppv-a-vs-b",
                    "streamNo":1,
                    "language":"English",
                    "hd":true,
                    "embedUrl":"https://embed.st/embed/admin/ppv-a-vs-b/1",
                    "source":"admin",
                    "viewers":12
                }]
            },{
                "title":"Upcoming",
                "time":"",
                "url":"/watch/upcoming",
                "groupId":"basketball",
                "sources":[]
            }]
        }]"#;
        let items = flatten_mut_streams(body).unwrap();
        assert_eq!(items.len(), 2);
        assert_eq!(items[0]["id"], "team-a-vs-team-b");
        assert_eq!(items[0]["catalog"], "mut");
        assert_eq!(items[0]["airing"], true);
        assert_eq!(items[0]["streams"].as_array().unwrap().len(), 1);
        assert_eq!(items[1]["airing"], false);
        assert!(items[1]["streams"].as_array().unwrap().is_empty());
    }

    #[test]
    fn flatten_mut_streams_rejects_html() {
        assert!(flatten_mut_streams("<!DOCTYPE html><html></html>").is_none());
    }
}
