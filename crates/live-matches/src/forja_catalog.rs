//! Native Forja Live schedule catalogs — one Rust fetch per plugin (RFC-065).

use serde_json::{json, Value};

use crate::espn;
use crate::fetch::{http_get_catalog, ok_items};

const BROWSER_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const WATCHFOOTY_MAX: usize = 80;

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
    if s.contains("football") || s.contains("soccer") {
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
        let genre = ev
            .pointer("/genre/name")
            .and_then(|v| v.as_str())
            .unwrap_or("other");
        out.push(json!({
            "id": id,
            "title": ev.get("name").and_then(|v| v.as_str()).unwrap_or("TimStreams event"),
            "category": norm_category(genre),
            "date": chrono_now_ms(),
            "poster": "",
            "popular": ev.get("featured").and_then(|v| v.as_bool()).unwrap_or(false),
            "airing": false,
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
    list.iter()
        .enumerate()
        .filter_map(|(i, m)| {
            let id = m
                .get("id")
                .map(|v| match v {
                    Value::String(s) => s.clone(),
                    Value::Number(n) => n.to_string(),
                    _ => i.to_string(),
                })
                .unwrap_or_else(|| i.to_string());
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
            Some(json!({
                "id": format!("sic_{id}"),
                "title": title,
                "category": category.to_lowercase(),
                "date": chrono_now_ms(),
                "poster": "",
                "popular": false,
                "airing": false,
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

fn watchfooty(config: &Value) -> Vec<Value> {
    let plugin_id = cfg_str(config, "providerId", "live-watchfooty");
    let api = cfg_str(
        config,
        "api",
        "https://api.watchfooty.st/api/v1/matches/football",
    );
    let body = match http_get_catalog(&api, &browser_headers(), 20) {
        Some(b) => b,
        None => return vec![],
    };
    let list: Vec<Value> = match serde_json::from_str(&body) {
        Ok(Value::Array(arr)) => arr,
        _ => return vec![],
    };
    let mut filtered: Vec<(i64, Value)> = list
        .into_iter()
        .filter_map(|item| {
            let status = item.get("status").and_then(|v| v.as_str()).unwrap_or("");
            let live = status == "in" || status == "live";
            let ts = item.get("timestamp").and_then(|v| v.as_i64()).unwrap_or(0);
            if !in_catalog_window(ts, live) {
                return None;
            }
            Some((ts, item))
        })
        .collect();
    filtered.sort_by_key(|(ts, _)| *ts);
    filtered
        .into_iter()
        .take(WATCHFOOTY_MAX)
        .filter_map(|(ts, item)| {
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
                .unwrap_or_else(|| format!("{away} vs {home}"));
            let live = item
                .get("status")
                .and_then(|v| v.as_str())
                .map(|s| s == "in" || s == "live")
                .unwrap_or(false);
            let date = if ts > 0 { ts } else { chrono_now_ms() };
            Some(json!({
                "id": format!("wf_{mid_s}"),
                "title": title,
                "category": "football",
                "date": date,
                "poster": "",
                "popular": live,
                "airing": live,
                "sources": [{ "source": "watchfooty", "id": mid_s }],
                "catalog": "forja_live",
                "pluginId": plugin_id,
            }))
        })
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
