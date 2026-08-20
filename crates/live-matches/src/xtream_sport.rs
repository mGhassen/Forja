//! Xtream live streams + short EPG → matcher candidates.

use std::collections::HashMap;

use base64::Engine;
use serde_json::{json, Value};
use tokio::task::JoinSet;

use crate::espn;
use crate::fetch::{self, http_get_async, http_get_json, ok_items};
use crate::sport_match::{self, Candidate, MatchGame};

const UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";

fn xtream_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), UA.into()),
        ("Accept".into(), "application/json".into()),
    ])
}

fn trim_base(url: &str) -> String {
    url.trim().trim_end_matches('/').to_string()
}

fn enc(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn decode_b64(value: &str) -> String {
    let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(value.trim()) else {
        return String::new();
    };
    String::from_utf8_lossy(&bytes).into_owned()
}

fn field_str(v: &Value, keys: &[&str]) -> String {
    for k in keys {
        if let Some(x) = v.get(*k) {
            match x {
                Value::String(s) => {
                    let t = s.trim();
                    if !t.is_empty() {
                        return t.to_string();
                    }
                }
                Value::Number(n) => return n.to_string(),
                _ => {}
            }
        }
    }
    String::new()
}

fn stream_category_ids(stream: &Value) -> Vec<String> {
    let mut out = Vec::new();
    let id = field_str(stream, &["category_id"]);
    if !id.is_empty() {
        out.push(id);
    }
    if let Some(arr) = stream.get("category_ids").and_then(|v| v.as_array()) {
        for x in arr {
            let id = match x {
                Value::String(s) => s.clone(),
                Value::Number(n) => n.to_string(),
                _ => continue,
            };
            if !id.is_empty() && !out.contains(&id) {
                out.push(id);
            }
        }
    }
    out
}

fn stream_in_categories(stream: &Value, category_ids: &[String]) -> bool {
    if category_ids.is_empty() {
        return true;
    }
    let set: std::collections::HashSet<&str> =
        category_ids.iter().map(|s| s.as_str()).collect();
    stream_category_ids(stream)
        .iter()
        .any(|id| set.contains(id.as_str()))
}

fn live_url(base: &str, user: &str, pass: &str, stream_id: &str, ext: &str) -> String {
    let ext = if ext.is_empty() { "m3u8" } else { ext };
    format!(
        "{}/live/{}/{}/{}.{}",
        trim_base(base),
        enc(user),
        enc(pass),
        enc(stream_id),
        ext
    )
}

fn fetch_live_streams(base: &str, user: &str, pass: &str) -> Vec<Value> {
    let url = format!(
        "{}/player_api.php?username={}&password={}&action=get_live_streams",
        trim_base(base),
        enc(user),
        enc(pass)
    );
    let body = match http_get_json(&url, &xtream_headers(), 25) {
        Some(b) => b,
        None => return vec![],
    };
    serde_json::from_str::<Vec<Value>>(&body).unwrap_or_default()
}

fn fetch_live_categories(base: &str, user: &str, pass: &str) -> HashMap<String, String> {
    let url = format!(
        "{}/player_api.php?username={}&password={}&action=get_live_categories",
        trim_base(base),
        enc(user),
        enc(pass)
    );
    let body = match http_get_json(&url, &xtream_headers(), 15) {
        Some(b) => b,
        None => return HashMap::new(),
    };
    let list = serde_json::from_str::<Vec<Value>>(&body).unwrap_or_default();
    let mut map = HashMap::new();
    for c in list {
        let id = field_str(&c, &["category_id"]);
        let name = field_str(&c, &["category_name"]);
        if !id.is_empty() {
            map.insert(id, name);
        }
    }
    map
}

struct EpgBits {
    text: String,
    start_timestamp: Option<f64>,
}

async fn fetch_short_epg_async(base: &str, user: &str, pass: &str, stream_id: &str) -> EpgBits {
    let url = format!(
        "{}/player_api.php?username={}&password={}&action=get_short_epg&stream_id={}&limit=1",
        trim_base(base),
        enc(user),
        enc(pass),
        enc(stream_id)
    );
    let body = match http_get_async(&url, &xtream_headers(), 5).await {
        Some(b) => b,
        None => {
            return EpgBits {
                text: String::new(),
                start_timestamp: None,
            };
        }
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => {
            return EpgBits {
                text: String::new(),
                start_timestamp: None,
            };
        }
    };
    let listings = root
        .get("epg_listings")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let Some(entry) = listings.first() else {
        return EpgBits {
            text: String::new(),
            start_timestamp: None,
        };
    };
    let title = decode_b64(&field_str(entry, &["title"]));
    let description = decode_b64(&field_str(entry, &["description"]));
    let text = format!("{title} {description}").trim().to_string();
    let start_timestamp = entry
        .get("start_timestamp")
        .and_then(|v| v.as_f64().or_else(|| v.as_i64().map(|n| n as f64)))
        .filter(|n| n.is_finite());
    EpgBits {
        text,
        start_timestamp,
    }
}

fn category_label_for(stream: &Value, cats: &HashMap<String, String>) -> String {
    for id in stream_category_ids(stream) {
        if let Some(n) = cats.get(&id) {
            if !n.is_empty() {
                return n.clone();
            }
        }
    }
    String::new()
}

async fn build_candidates_async(
    base: &str,
    user: &str,
    pass: &str,
    filtered: Vec<Value>,
    cats: HashMap<String, String>,
) -> Vec<Candidate> {
    let mut set = JoinSet::new();
    for s in filtered {
        let base = base.to_string();
        let user = user.to_string();
        let pass = pass.to_string();
        let cats = cats.clone();
        set.spawn(async move {
            let stream_id = field_str(&s, &["stream_id"]);
            if stream_id.is_empty() {
                return None;
            }
            let name = field_str(&s, &["name"]);
            let ext = field_str(&s, &["container_extension"]);
            let ext = if ext.is_empty() {
                "m3u8".into()
            } else {
                ext
            };
            let label = category_label_for(&s, &cats);
            let epg = fetch_short_epg_async(&base, &user, &pass, &stream_id).await;
            Some(Candidate {
                name,
                description: epg.text,
                start_timestamp: epg.start_timestamp,
                stream_url: live_url(&base, &user, &pass, &stream_id, &ext),
                category_label: label,
            })
        });
    }
    let mut out = Vec::new();
    while let Some(res) = set.join_next().await {
        if let Ok(Some(c)) = res {
            out.push(c);
        }
    }
    out
}

/// Build candidates + run matcher.
pub fn sport_match_streams(game: &Value, xtream: &Value, category_ids: &[String]) -> String {
    let base = field_str(xtream, &["url", "baseUrl"]);
    let user = field_str(xtream, &["username", "user"]);
    let pass = field_str(xtream, &["password", "pass"]);
    if base.is_empty() || user.is_empty() {
        return json!({ "error": "xtream url and username required" }).to_string();
    }

    let sport = field_str(game, &["sport"]);
    let match_game = MatchGame::from_json(game);

    let streams = fetch_live_streams(&base, &user, &pass);
    let filtered: Vec<Value> = streams
        .into_iter()
        .filter(|s| stream_in_categories(s, category_ids))
        .collect();
    let cats = fetch_live_categories(&base, &user, &pass);

    let candidates = fetch::block_on(build_candidates_async(
        &base, &user, &pass, filtered, cats,
    ));

    let team_names = espn::fetch_all_team_names(&sport);
    let items = sport_match::match_streams(&match_game, &candidates, &team_names);
    ok_items(items)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stream_category_filter() {
        let s = json!({"category_id": "12", "name": "NBA"});
        assert!(stream_in_categories(&s, &["12".into()]));
        assert!(!stream_in_categories(&s, &["99".into()]));
        let n = json!({"category_id": 12});
        assert!(stream_in_categories(&n, &["12".into()]));
    }

    #[test]
    fn builds_live_url() {
        let u = live_url("http://x.com/", "u", "p", "42", "m3u8");
        assert_eq!(u, "http://x.com/live/u/p/42.m3u8");
    }
}
