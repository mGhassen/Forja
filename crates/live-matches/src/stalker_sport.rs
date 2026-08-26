//! Stalker live catalog + MAG short EPG → matcher candidates.
//!
//! Play URLs are deferred (`create_link` at host play time). Candidates carry
//! `stream_id` = cmd and `epg_channel_id` = numeric ITV `ch_id`.

use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use serde_json::{json, Value};
use tokio::sync::Semaphore;
use tokio::task::JoinSet;

use crate::espn;
use crate::fetch::{self, ok_items};
use crate::sport_match::{self, Candidate, MatchGame};

const LIVE_CACHE_TTL: Duration = Duration::from_secs(120);
const EPG_CONCURRENCY: usize = 12;
const MAX_EPG_FETCHES: usize = 120;

struct PortalLiveCacheEntry {
    streams: Vec<Value>,
    categories: HashMap<String, String>,
    fetched_at: Instant,
}

fn live_cache() -> &'static Mutex<HashMap<String, PortalLiveCacheEntry>> {
    static CACHE: OnceLock<Mutex<HashMap<String, PortalLiveCacheEntry>>> = OnceLock::new();
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn portal_cache_key(url: &str, mac: &str) -> String {
    format!("{}|{}", url.trim().trim_end_matches('/'), mac.trim())
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

fn absolutize_logo(base: &str, logo: &str) -> String {
    let logo = logo.trim();
    if logo.is_empty() {
        return String::new();
    }
    if logo.starts_with("http://") || logo.starts_with("https://") {
        return logo.to_string();
    }
    if logo.starts_with("//") {
        return format!("https:{logo}");
    }
    let base = base.trim().trim_end_matches('/');
    if base.is_empty() {
        return logo.to_string();
    }
    format!("{}/{}", base, logo.trim_start_matches('/'))
}

fn skeleton_candidate(portal_url: &str, s: &Value, cats: &HashMap<String, String>) -> Option<Candidate> {
    let stream_id = field_str(s, &["stream_id"]);
    if stream_id.is_empty() {
        return None;
    }
    let epg_channel_id = field_str(s, &["epg_channel_id"]);
    let name = field_str(s, &["name"]);
    let logo = absolutize_logo(
        portal_url,
        &field_str(s, &["icon", "stream_icon", "logo", "cover"]),
    );
    Some(Candidate {
        name,
        description: String::new(),
        start_timestamp: None,
        stream_url: String::new(),
        category_label: category_label_for(s, cats),
        logo,
        stream_id,
        epg_channel_id,
    })
}

fn parse_catalog(raw: &str) -> Result<(Vec<Value>, HashMap<String, String>), String> {
    let root: Value = serde_json::from_str(raw).map_err(|e| e.to_string())?;
    if let Some(err) = root.get("error").and_then(|v| v.as_str()) {
        return Err(err.to_string());
    }
    let streams = root
        .get("streams")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut cats = HashMap::new();
    if let Some(arr) = root.get("categories").and_then(|v| v.as_array()) {
        for c in arr {
            let id = field_str(c, &["id", "category_id"]);
            let name = field_str(c, &["name", "category_name"]);
            if !id.is_empty() {
                cats.insert(id, name);
            }
        }
    }
    Ok((streams, cats))
}

fn get_or_fetch_portal_live(
    url: &str,
    mac: &str,
    serial: &str,
) -> Result<(Vec<Value>, HashMap<String, String>), String> {
    let key = portal_cache_key(url, mac);
    if let Ok(cache) = live_cache().lock() {
        if let Some(entry) = cache.get(&key) {
            if entry.fetched_at.elapsed() < LIVE_CACHE_TTL {
                return Ok((entry.streams.clone(), entry.categories.clone()));
            }
        }
    }
    let req = json!({
        "action": "catalog",
        "url": url,
        "username": mac,
        "password": serial,
        "section": "live",
        "timeout_secs": 60,
    });
    let raw = fetch::block_on(iptv::stalker_client::request_json_async(&req.to_string()));
    let (streams, cats) = parse_catalog(&raw)?;
    if let Ok(mut cache) = live_cache().lock() {
        cache.insert(
            key,
            PortalLiveCacheEntry {
                streams: streams.clone(),
                categories: cats.clone(),
                fetched_at: Instant::now(),
            },
        );
    }
    Ok((streams, cats))
}

struct EpgBits {
    text: String,
    start_timestamp: Option<f64>,
}

async fn fetch_short_epg_async(url: &str, mac: &str, serial: &str, channel_id: &str) -> EpgBits {
    if channel_id.trim().is_empty() {
        return EpgBits {
            text: String::new(),
            start_timestamp: None,
        };
    }
    let req = json!({
        "action": "epg",
        "url": url,
        "username": mac,
        "password": serial,
        "channel_id": channel_id,
        "limit": 1,
        "timeout_secs": 15,
    });
    let raw = iptv::stalker_client::request_json_async(&req.to_string()).await;
    let root: Value = match serde_json::from_str(&raw) {
        Ok(v) => v,
        Err(_) => {
            return EpgBits {
                text: String::new(),
                start_timestamp: None,
            };
        }
    };
    if root.get("error").is_some() {
        return EpgBits {
            text: String::new(),
            start_timestamp: None,
        };
    }
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
    let title = field_str(entry, &["title"]);
    let description = field_str(entry, &["description"]);
    let text = format!("{title} {description}").trim().to_string();
    let start_timestamp = entry
        .get("start_timestamp")
        .and_then(|v| match v {
            Value::Number(n) => n.as_f64(),
            Value::String(s) => s.parse::<f64>().ok(),
            _ => None,
        })
        .filter(|n| n.is_finite());
    EpgBits {
        text,
        start_timestamp,
    }
}

async fn fill_epg_async(
    url: &str,
    mac: &str,
    serial: &str,
    candidates: &mut [Candidate],
    indices: &[usize],
) {
    if indices.is_empty() {
        return;
    }
    let sem = Arc::new(Semaphore::new(EPG_CONCURRENCY));
    let mut set = JoinSet::new();
    for &idx in indices {
        let Some(c) = candidates.get(idx) else {
            continue;
        };
        let channel_id = if !c.epg_channel_id.is_empty() {
            c.epg_channel_id.clone()
        } else {
            continue;
        };
        let url = url.to_string();
        let mac = mac.to_string();
        let serial = serial.to_string();
        let sem = Arc::clone(&sem);
        set.spawn(async move {
            let _permit = sem.acquire_owned().await.ok();
            let epg = fetch_short_epg_async(&url, &mac, &serial, &channel_id).await;
            (idx, epg)
        });
    }
    while let Some(res) = set.join_next().await {
        if let Ok((idx, epg)) = res {
            if let Some(c) = candidates.get_mut(idx) {
                c.description = epg.text;
                c.start_timestamp = epg.start_timestamp;
            }
        }
    }
}

/// Build Stalker candidates + run matcher. URLs stay empty until host create_link.
pub fn sport_match_streams(
    game: &Value,
    stalker: &Value,
    category_ids: &[String],
    skip_epg: bool,
) -> String {
    let url = field_str(stalker, &["url", "baseUrl"]);
    let mac = field_str(stalker, &["username", "user", "mac"]);
    let serial = field_str(stalker, &["password", "pass", "serial"]);
    if url.is_empty() || mac.is_empty() {
        return json!({ "error": "stalker url and username (MAC) required" }).to_string();
    }

    let sport = field_str(game, &["sport"]);
    let match_game = MatchGame::from_json(game);

    let (streams, cats) = match get_or_fetch_portal_live(&url, &mac, &serial) {
        Ok(v) => v,
        Err(e) => return json!({ "error": e }).to_string(),
    };
    let filtered: Vec<Value> = streams
        .into_iter()
        .filter(|s| stream_in_categories(s, category_ids))
        .collect();

    let mut candidates: Vec<Candidate> = filtered
        .iter()
        .filter_map(|s| skeleton_candidate(&url, s, &cats))
        .collect();

    if skip_epg {
        let items = sport_match::match_streams(&match_game, &candidates, &[]);
        return ok_items(items);
    }

    let epg_idxs = sport_match::indices_for_epg(&match_game, &candidates, MAX_EPG_FETCHES);
    fetch::block_on(fill_epg_async(
        &url, &mac, &serial, &mut candidates, &epg_idxs,
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
    }

    #[test]
    fn skeleton_keeps_cmd_and_epg_id_without_url() {
        let s = json!({
            "stream_id": "ffmpeg http://x/stream/42",
            "epg_channel_id": "42",
            "name": "ESPN",
            "icon": "http://logo/espn.png",
            "category_id": "5",
        });
        let mut cats = HashMap::new();
        cats.insert("5".into(), "Sports".into());
        let c = skeleton_candidate("http://portal.example/c/", &s, &cats).expect("cand");
        assert!(c.stream_url.is_empty());
        assert_eq!(c.stream_id, "ffmpeg http://x/stream/42");
        assert_eq!(c.epg_channel_id, "42");
        assert_eq!(c.category_label, "Sports");
    }

    #[test]
    fn empty_url_candidates_survive_match_flatten() {
        let game = MatchGame::from_json(&json!({
            "homeTeam": "Boston Red Sox",
            "awayTeam": "Toronto Blue Jays",
            "homeNick": "Red Sox",
            "awayNick": "Blue Jays",
            "title": "Red Sox vs Blue Jays",
            "dateMs": 1_700_000_000_000i64,
        }));
        let cands = vec![Candidate {
            name: "Red Sox vs Blue Jays".into(),
            description: String::new(),
            start_timestamp: None,
            stream_url: String::new(),
            category_label: "MLB".into(),
            logo: String::new(),
            stream_id: "cmd://42".into(),
            epg_channel_id: "42".into(),
        }];
        let hits = sport_match::match_streams(&game, &cands, &[]);
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].get("url").and_then(|v| v.as_str()), Some(""));
        assert_eq!(
            hits[0].get("epg_channel_id").and_then(|v| v.as_str()),
            Some("42")
        );
        assert_eq!(
            hits[0].get("stream_id").and_then(|v| v.as_str()),
            Some("cmd://42")
        );
    }
}
