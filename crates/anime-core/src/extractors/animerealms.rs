use std::collections::HashMap;

use serde_json::{json, Value};

use super::common::{anime_post, AnimeTrackOut, StreamResultOut, DEFAULT_UA};

const BASE_URL: &str = "https://www.animerealms.org";

pub const DEFAULT_PROVIDERS: &[&str] = &[
    "hianime",
    "allmanga",
    "gogoanime",
    "zencloud",
    "animepahe",
    "animez",
    "animekai",
    "kickassanime",
    "anizone",
    "febbox",
    "hanime-tv",
];

fn headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Referer".into(), format!("{BASE_URL}/")),
        ("Origin".into(), BASE_URL.into()),
    ])
}

fn get_streams(provider: &str, anilist_id: i64, episode: i32) -> Result<Value, String> {
    let body = json!({
        "provider": provider,
        "anilistId": anilist_id,
        "episodeNumber": episode,
    });
    let mut hdrs = headers();
    hdrs.insert("Content-Type".into(), "application/json".into());
    let resp = anime_post(
        &format!("{BASE_URL}/api/watch"),
        &hdrs,
        &body.to_string(),
        15,
    )?;
    if resp.status != 200 {
        return Err(format!("AnimeRealms watch HTTP {}", resp.status));
    }
    serde_json::from_str(&resp.body).map_err(|e| e.to_string())
}

pub fn animerealms_streams(
    anilist_id: i64,
    episode: i32,
    provider: &str,
) -> Result<Value, String> {
    let data = get_streams(provider, anilist_id, episode)?;
    let streams = data.get("streams").and_then(|v| v.as_array()).cloned().unwrap_or_default();
    let real: Vec<&Value> = streams
        .iter()
        .filter(|s| {
            s.get("url")
                .and_then(|v| v.as_str())
                .map(|u| !u.contains("test-streams.mux.dev"))
                .unwrap_or(false)
        })
        .collect();
    if real.is_empty() {
        return Ok(json!({ "result": null }));
    }
    let first = real[0];
    let url = first.get("url").and_then(|v| v.as_str()).unwrap_or("").to_string();

    let mut tracks = Vec::new();
    if let Some(subs) = data.get("subtitles").and_then(|v| v.as_array()) {
        for t in subs {
            let su = t.get("url").and_then(|v| v.as_str()).unwrap_or("");
            if su.is_empty() {
                continue;
            }
            tracks.push(AnimeTrackOut {
                url: su.to_string(),
                label: t
                    .get("lang")
                    .or_else(|| t.get("label"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                language: String::new(),
                is_default: t.get("default") == Some(&Value::Bool(true)),
            });
        }
    }

    Ok(json!({
        "result": StreamResultOut {
            url,
            referer: format!("{BASE_URL}/"),
            origin: BASE_URL.to_string(),
            tracks,
            provider: provider.to_string(),
            stream_label: None,
        }
    }))
}