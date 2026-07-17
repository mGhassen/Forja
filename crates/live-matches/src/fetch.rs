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
const CDN_CHANNELS_URL: &str =
    "https://api.cdn-live.tv/api/v1/channels/?user=cdnlivetv&plan=free";
const CDN_SPORTS_URL: &str =
    "https://api.cdn-live.tv/api/v1/events/sports/?user=cdnlivetv&plan=free";
const CDN_SPORT_KEYS: &[&str] = &["Soccer", "NFL", "NBA", "NHL"];

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

fn ok_items(items: Vec<Value>) -> String {
    json!({ "items": items }).to_string()
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

pub fn cdn_channels() -> String {
    let body = match http_get(CDN_CHANNELS_URL, &ppv_headers(), 12) {
        Some(b) => b,
        None => return ok_items(vec![]),
    };
    let parsed: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return ok_items(vec![]),
    };
    let items = parsed
        .get("channels")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    ok_items(items)
}

pub fn cdn_sports() -> String {
    let body = match http_get(CDN_SPORTS_URL, &ppv_headers(), 12) {
        Some(b) => b,
        None => return ok_items(vec![]),
    };
    let parsed: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return ok_items(vec![]),
    };
    let cdn_data = match parsed.get("cdn-live-tv") {
        Some(v) => v,
        None => return ok_items(vec![]),
    };
    let mut result = Vec::new();
    for key in CDN_SPORT_KEYS {
        if let Some(events) = cdn_data.get(*key).and_then(|v| v.as_array()) {
            for e in events {
                let mut event = e.clone();
                // Preserve the parent sport bucket (Soccer / NFL / …) so the
                // host can merge CDN into unified All-servers sport chips.
                if let Some(obj) = event.as_object_mut() {
                    obj.insert("sport".into(), Value::String((*key).to_string()));
                }
                result.push(event);
            }
        }
    }
    ok_items(result)
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
    fn cdn_sports_injects_sport_bucket() {
        let cdn_data = json!({
            "Soccer": [{"gameID": "1", "tournament": "EPL"}],
            "NBA": [{"gameID": "2", "tournament": "NBA"}]
        });
        let keys = ["Soccer", "NFL", "NBA", "NHL"];
        let mut result = Vec::new();
        for key in keys {
            if let Some(events) = cdn_data.get(key).and_then(|v| v.as_array()) {
                for e in events {
                    let mut event = e.clone();
                    if let Some(obj) = event.as_object_mut() {
                        obj.insert("sport".into(), Value::String(key.to_string()));
                    }
                    result.push(event);
                }
            }
        }
        assert_eq!(result.len(), 2);
        assert_eq!(result[0]["sport"], "Soccer");
        assert_eq!(result[1]["sport"], "NBA");
    }
}
