//! Native Forja Live schedule catalogs — one Rust fetch per plugin (RFC-065).

use serde_json::{json, Value};

use crate::espn;
use crate::fetch::{http_get_catalog, ok_items};

const BROWSER_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const WATCHFOOTY_MAX: usize = 120;
const WATCHFOOTY_API_ORIGIN: &str = "https://api.watchfooty.st";
const WATCHFOOTY_LIVE_API: &str = "https://api.watchfooty.st/api/v1/matches/live";
const WATCHFOOTY_CATALOG_API: &str = "https://api.watchfooty.st/api/v1/matches/all";

fn browser_headers() -> std::collections::HashMap<String, String> {
    std::collections::HashMap::from([
        ("User-Agent".into(), BROWSER_UA.into()),
        ("Accept".into(), "application/json".into()),
    ])
}

fn cfg_str(config: &Value, key: &str, default: &str) -> String {
    config
        .get(key)
        .and_then(|v| v.as_str())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| default.to_string())
}

fn norm_category(raw: &str) -> String {
    let s = raw.trim().to_lowercase();
    if s.contains("football") || s.contains("soccer") || s.contains("pilkanozna") || s.contains("pilka")
    {
        return "football".into();
    }
    if s.contains("basket") {
        return "basketball".into();
    }
    if s.contains("hockey") || s.contains("nhl") {
        return "hockey".into();
    }
    if s.contains("mma") || s.contains("ufc") {
        return "mma".into();
    }
    s.replace(' ', "-")
}

fn streamic_catalog_window(ts: i64) -> bool {
    if ts <= 0 {
        return false;
    }
    let ms = if ts >= 1_000_000_000_000 {
        ts
    } else {
        ts * 1000
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    ms >= now - 24 * 3_600_000 && ms <= now + 7 * 24 * 3_600_000
}

fn streamic_is_airing(start_time: i64) -> bool {
    if start_time <= 0 {
        return false;
    }
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    start_time <= now && start_time >= now - 6 * 3600
}

fn in_catalog_window(ts: i64, live: bool) -> bool {
    if live {
        return true;
    }
    if ts <= 0 {
        return false;
    }
    let ms = if ts >= 1_000_000_000_000 {
        ts
    } else {
        ts * 1000
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    ms >= now - 3 * 3_600_000 && ms <= now + 24 * 3_600_000
}

fn timstreams_genre_category(ev: &Value) -> String {
    if let Some(id) = ev.get("genre").and_then(|v| v.as_i64()) {
        let cat = match id {
            1 => "football",
            2 => "motorsport",
            3 | 5 => "mma",
            4 => "hockey",
            6 => "tennis",
            7 => "basketball",
            8 => "american-football",
            9 => "baseball",
            _ => "other",
        };
        if cat != "other" {
            return cat.into();
        }
    }
    let genre = ev
        .pointer("/genre/name")
        .and_then(|v| v.as_str())
        .unwrap_or("other");
    norm_category(genre)
}

fn timstreams_event_time(ev: &Value) -> i64 {
    let Some(raw) = ev.get("time").and_then(|v| v.as_str()) else {
        return 0;
    };
    let (date, time) = match raw.split_once('T') {
        Some(parts) => parts,
        None => return 0,
    };
    let mut dp = date.split('-');
    let year: i64 = dp.next().and_then(|s| s.parse().ok()).unwrap_or(0);
    let month: i64 = dp.next().and_then(|s| s.parse().ok()).unwrap_or(0);
    let day: i64 = dp.next().and_then(|s| s.parse().ok()).unwrap_or(0);
    let hour: i64 = time.get(0..2).and_then(|s| s.parse().ok()).unwrap_or(0);
    let minute: i64 = time.get(3..5).and_then(|s| s.parse().ok()).unwrap_or(0);
    if year <= 0 || !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return 0;
    }
    let days = (year - 1970) * 365
        + (year - 1969) / 4
        - (year - 1901) / 100
        + (year - 1601) / 400
        + [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334][(month - 1) as usize]
        + day
        - 1;
    days * 86_400 + hour * 3600 + minute * 60
}

fn timstreams_is_airing(start_time: i64) -> bool {
    if start_time <= 0 {
        return false;
    }
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    start_time <= now && start_time >= now - 6 * 3600
}

fn timstreams(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "live-timstreams");
    let api = cfg_str(
        config,
        "api",
        "https://timstreams.st/api/live-upcoming",
    );
    let body = match http_get_catalog(&api, &browser_headers(), 20) {
        Some(b) => b,
        None => return vec![],
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let events = root
        .get("events")
        .and_then(|e| e.as_array())
        .cloned()
        .unwrap_or_default();
    let mut out = Vec::new();
    for (idx, ev) in events.iter().enumerate() {
        let sources: Vec<Value> = ev
            .get("streams")
            .and_then(|s| s.as_array())
            .map(|arr| {
                arr.iter()
                    .filter(|st| st.get("vip").and_then(|v| v.as_bool()) != Some(true))
                    .enumerate()
                    .map(|(i, st)| {
                        json!({
                            "source": "timstreams",
                            "id": st.get("name").and_then(|v| v.as_str()).unwrap_or(&i.to_string()),
                        })
                    })
                    .collect()
            })
            .unwrap_or_default();
        if sources.is_empty() {
            continue;
        }
        let url = ev.get("url").and_then(|v| v.as_str()).unwrap_or("");
        let id = if url.is_empty() {
            format!("ts_{idx}")
        } else {
            format!("ts_{url}")
        };
        let start_time = timstreams_event_time(ev);
        let airing = timstreams_is_airing(start_time);
        let viewers = ev.get("viewers").and_then(|v| v.as_i64()).unwrap_or(0);
        out.push(json!({
            "id": id,
            "title": ev.get("name").and_then(|v| v.as_str()).unwrap_or("TimStreams event"),
            "category": timstreams_genre_category(ev),
            "date": if start_time > 0 { start_time } else { chrono_now_ms() },
            "poster": ev.get("logo").and_then(|v| v.as_str()).unwrap_or(""),
            "popular": ev.get("featured").and_then(|v| v.as_bool()).unwrap_or(false) || viewers > 100,
            "airing": airing,
            "sources": sources,
            "catalog": "forja_live",
            "pluginId": plugin_id,
        }));
    }
    out
}

fn chrono_now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

fn streamic(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "live-streamic");
    let api = cfg_str(config, "api", "https://streamic.st/api/J.php");
    let body = match http_get_catalog(&api, &browser_headers(), 20) {
        Some(b) => b,
        None => return vec![],
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let list = if let Some(arr) = root.as_array() {
        arr.clone()
    } else {
        root.get("events")
            .or_else(|| root.get("streams"))
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default()
    };
    let mut filtered: Vec<(i64, Value)> = list
        .into_iter()
        .filter_map(|m| {
            let start_time = m.get("startTime").and_then(|v| v.as_i64()).unwrap_or(0);
            if !streamic_catalog_window(start_time) {
                return None;
            }
            Some((start_time, m))
        })
        .collect();
    filtered.sort_by_key(|(ts, _)| *ts);
    filtered
        .into_iter()
        .take(WATCHFOOTY_MAX)
        .filter_map(|(start_time, m)| {
            let id = m
                .get("id")
                .map(|v| match v {
                    Value::String(s) => s.clone(),
                    Value::Number(n) => n.to_string(),
                    _ => String::new(),
                })
                .filter(|s| !s.is_empty())?;
            let title = m
                .get("title")
                .or_else(|| m.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("Streamic");
            let category = m
                .get("sport")
                .or_else(|| m.get("category"))
                .and_then(|v| v.as_str())
                .unwrap_or("other");
            let airing = streamic_is_airing(start_time);
            Some(json!({
                "id": format!("sic_{id}"),
                "title": title,
                "category": norm_category(category),
                "date": if start_time > 0 { start_time } else { chrono_now_ms() },
                "poster": "",
                "popular": airing,
                "airing": airing,
                "sources": [{ "source": "streamic", "id": id }],
                "catalog": "forja_live",
                "pluginId": plugin_id,
            }))
        })
        .collect()
}

fn streamfree(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "live-streamfree");
    let origin = cfg_str(config, "origin", "https://streamfree.top")
        .trim_end_matches('/')
        .to_string();
    let url = format!("{origin}/streams");
    let body = match http_get_catalog(&url, &browser_headers(), 20) {
        Some(b) => b,
        None => return vec![],
    };
    let root: Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let streams = root
        .get("streams")
        .and_then(|v| v.as_object())
        .cloned()
        .unwrap_or_default();
    let mut out = Vec::new();
    for (category, entries) in streams {
        let Some(arr) = entries.as_array() else {
            continue;
        };
        for s in arr {
            let id = match s
                .get("stream_key")
                .or_else(|| s.get("id"))
                .map(|v| match v {
                    Value::String(x) => x.clone(),
                    Value::Number(n) => n.to_string(),
                    _ => String::new(),
                })
                .filter(|x| !x.is_empty())
            {
                Some(id) => id,
                None => continue,
            };
            let viewers = s.get("viewers").and_then(|v| v.as_i64()).unwrap_or(0);
            let ts = s.get("match_timestamp").and_then(|v| v.as_i64()).unwrap_or(0);
            out.push(json!({
                "id": format!("sf_{id}"),
                "title": s.get("name").and_then(|v| v.as_str()).unwrap_or(""),
                "category": category.to_lowercase(),
                "date": if ts > 0 { ts * 1000 } else { 0 },
                "poster": s.get("thumbnail_url").and_then(|v| v.as_str()).unwrap_or(""),
                "popular": viewers > 100,
                "airing": false,
                "sources": [{ "source": "streamfree", "id": id }],
                "catalog": "forja_live",
                "pluginId": plugin_id,
            }));
        }
    }
    out
}

fn watchfooty_abs_url(path: &str) -> String {
    let p = path.trim();
    if p.is_empty() {
        return String::new();
    }
    if p.starts_with("http://") || p.starts_with("https://") {
        return p.to_string();
    }
    if p.starts_with('/') {
        format!("{WATCHFOOTY_API_ORIGIN}{p}")
    } else {
        format!("{WATCHFOOTY_API_ORIGIN}/{p}")
    }
}

fn watchfooty_norm_sport(raw: &str) -> String {
    let s = raw.trim().to_lowercase();
    if s.is_empty() {
        return "football".into();
    }
    if s.contains("soccer") {
        return "football".into();
    }
    if s.contains("american") && s.contains("football") {
        return "american-football".into();
    }
    s.replace(' ', "-")
}

fn watchfooty_row(plugin_id: &str, ts: i64, airing: bool, item: &Value) -> Option<Value> {
    let mid = item.get("matchId")?;
    let mid_s = match mid {
        Value::String(s) => s.clone(),
        Value::Number(n) => n.to_string(),
        _ => return None,
    };
    let home = item
        .pointer("/teams/home/name")
        .and_then(|v| v.as_str())
        .unwrap_or("Home");
    let away = item
        .pointer("/teams/away/name")
        .and_then(|v| v.as_str())
        .unwrap_or("Away");
    let title = item
        .get("title")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .unwrap_or_else(|| format!("{home} vs {away}"));
    let sport = item
        .get("sport")
        .and_then(|v| v.as_str())
        .unwrap_or("football");
    let poster = item
        .get("poster")
        .and_then(|v| v.as_str())
        .map(watchfooty_abs_url)
        .unwrap_or_default();
    let date = if ts > 0 { ts } else { chrono_now_ms() };
    Some(json!({
        "id": format!("wf_{mid_s}"),
        "title": title,
        "category": watchfooty_norm_sport(sport),
        "date": date,
        "poster": poster,
        // Site Live board often hides stream-less rows; we keep them as airing
        // so Status → Airing can still show catalog lives.
        "popular": airing,
        "airing": airing,
        "sources": [{ "source": "watchfooty", "id": mid_s }],
        "catalog": "forja_live",
        "pluginId": plugin_id,
    }))
}

fn watchfooty_fetch_array(url: &str) -> Vec<Value> {
    let body = match http_get_catalog(url, &browser_headers(), 20) {
        Some(b) => b,
        None => return vec![],
    };
    match serde_json::from_str(&body) {
        Ok(Value::Array(arr)) => arr,
        _ => vec![],
    }
}

fn watchfooty(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "live-watchfooty");
    // Optional override still hits a single list; default merges live+upcoming.
    let api_override = config
        .get("api")
        .and_then(|v| v.as_str())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let mut by_id: std::collections::BTreeMap<String, (i64, bool, Value)> =
        std::collections::BTreeMap::new();

    let live_url = api_override
        .clone()
        .unwrap_or_else(|| WATCHFOOTY_LIVE_API.to_string());
    for item in watchfooty_fetch_array(&live_url) {
        let status = item.get("status").and_then(|v| v.as_str()).unwrap_or("");
        let status_live = status == "in" || status == "live";
        if !status_live {
            continue;
        }
        // Keep stream-less airing rows — UI Status filter chooses visibility.
        let ts = item.get("timestamp").and_then(|v| v.as_i64()).unwrap_or(0);
        let mid = match item.get("matchId") {
            Some(Value::String(s)) => s.clone(),
            Some(Value::Number(n)) => n.to_string(),
            _ => continue,
        };
        by_id.insert(mid, (ts, true, item));
    }

    if api_override.is_none() {
        for item in watchfooty_fetch_array(WATCHFOOTY_CATALOG_API) {
            let status = item.get("status").and_then(|v| v.as_str()).unwrap_or("");
            // Upcoming only — post/finished inflate fake LIVE via UI heuristics.
            if status != "pre" {
                continue;
            }
            let ts = item.get("timestamp").and_then(|v| v.as_i64()).unwrap_or(0);
            if !in_catalog_window(ts, false) {
                continue;
            }
            let mid = match item.get("matchId") {
                Some(Value::String(s)) => s.clone(),
                Some(Value::Number(n)) => n.to_string(),
                _ => continue,
            };
            by_id.entry(mid).or_insert((ts, false, item));
        }
    }

    let mut filtered: Vec<(i64, bool, Value)> = by_id.into_values().collect();
    filtered.sort_by(|a, b| match (a.1, b.1) {
        (true, false) => std::cmp::Ordering::Less,
        (false, true) => std::cmp::Ordering::Greater,
        _ => a.0.cmp(&b.0),
    });
    filtered
        .into_iter()
        .take(WATCHFOOTY_MAX)
        .filter_map(|(ts, airing, item)| watchfooty_row(&plugin_id, ts, airing, &item))
        .collect()
}

fn espn(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "catalog-espn");
    let leagues: Vec<String> = config
        .get("leagues")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|x| x.as_str().map(|s| s.trim().to_uppercase()))
                .filter(|s| !s.is_empty())
                .collect()
        })
        .unwrap_or_default();
    let date = config.get("date").and_then(|v| v.as_str());
    espn::forja_live_catalog_rows(&leagues, date, &plugin_id)
}

/// Fetch one Forja Live catalog plugin by engine id (`catalog-*`).
pub fn fetch_catalog(catalog_id: &str, config: &Value) -> String {
    let id = catalog_id.trim();
    let items = match id {
        "catalog-espn" => espn(config),
        "catalog-timstreams" => timstreams(config),
        "catalog-streamic" => streamic(config),
        "catalog-streamfree" => streamfree(config),
        "catalog-watchfooty" => watchfooty(config),
        _ => vec![],
    };
    ok_items(items)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn norm_category_maps_soccer() {
        assert_eq!(norm_category("Soccer"), "football");
        assert_eq!(norm_category("Premier Football"), "football");
    }

    #[test]
    fn norm_category_maps_polish_football() {
        assert_eq!(norm_category("pilkanozna_wazne"), "football");
    }

    #[test]
    fn streamic_catalog_window_accepts_recent_kickoff() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        assert!(streamic_catalog_window(now - 3600));
    }

    #[test]
    fn streamic_is_airing_when_started_recently() {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);
        assert!(streamic_is_airing(now - 1800));
        assert!(!streamic_is_airing(now + 3600));
    }

    #[test]
    fn timstreams_genre_maps_nfl() {
        let ev = json!({ "genre": 8, "name": "Saints @ Rams" });
        assert_eq!(timstreams_genre_category(&ev), "american-football");
    }

    #[test]
    fn timstreams_event_time_parses_iso_local() {
        let ev = json!({ "time": "2026-08-22T18:00" });
        assert!(timstreams_event_time(&ev) > 0);
    }

    #[test]
    fn in_catalog_window_live_always_true() {
        assert!(in_catalog_window(0, true));
    }

    #[test]
    fn unknown_catalog_returns_empty_items() {
        let raw = fetch_catalog("catalog-nope", &json!({}));
        let parsed: Value = serde_json::from_str(&raw).unwrap();
        assert!(parsed.get("items").unwrap().as_array().unwrap().is_empty());
    }
}
