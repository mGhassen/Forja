use std::collections::HashMap;

use regex::Regex;
use serde_json::Value;

use crate::extractors::common::{anime_get, AnimeTrackOut, StreamResultOut, DEFAULT_UA};

const DEFAULT_REFERER: &str = "https://www.enma.lol/";

pub fn direct_embed_extract(embed_url: &str, referer: Option<&str>) -> Result<Option<StreamResultOut>, String> {
    let embed_url = embed_url.trim();
    if embed_url.is_empty() || !embed_url.starts_with("http") {
        return Ok(None);
    }

    let embed_uri_host = embed_url
        .strip_prefix("https://")
        .or_else(|| embed_url.strip_prefix("http://"))
        .and_then(|rest| rest.split('/').next())
        .unwrap_or("");
    let scheme = if embed_url.starts_with("https://") {
        "https"
    } else {
        "http"
    };
    let origin = format!("{scheme}://{embed_uri_host}");
    let referer = referer.unwrap_or(DEFAULT_REFERER);

    let page_headers = HashMap::from([
        ("Referer".into(), referer.into()),
        ("User-Agent".into(), DEFAULT_UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
        ),
    ]);

    let page = anime_get(embed_url, &page_headers, 15)?;
    if page.status != 200 {
        return Ok(None);
    }

    let re = Regex::new(r#"data-id\s*=\s*"(\d+)""#).map_err(|e| e.to_string())?;
    let Some(cap) = re.captures(&page.body) else {
        return Ok(None);
    };
    let data_id = cap.get(1).map(|m| m.as_str()).unwrap_or("");
    if data_id.is_empty() {
        return Ok(None);
    }

    let api_url = format!("{origin}/stream/getSources?id={data_id}");
    let api_headers = HashMap::from([
        ("Referer".into(), embed_url.into()),
        ("Origin".into(), origin.clone()),
        ("X-Requested-With".into(), "XMLHttpRequest".into()),
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
    ]);

    let api = anime_get(&api_url, &api_headers, 15)?;
    if api.status != 200 {
        return Ok(None);
    }

    let json: Value = serde_json::from_str(&api.body).map_err(|e| e.to_string())?;
    let file = json
        .pointer("/sources/file")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    if file.is_empty() {
        return Ok(None);
    }

    let mut tracks = Vec::new();
    if let Some(raw) = json.get("tracks").and_then(|v| v.as_array()) {
        for t in raw {
            let kind = t.get("kind").and_then(|v| v.as_str()).unwrap_or("captions");
            if kind != "captions" && kind != "subtitles" {
                continue;
            }
            let Some(url) = t.get("file").and_then(|v| v.as_str()) else {
                continue;
            };
            tracks.push(AnimeTrackOut {
                url: url.to_string(),
                label: t
                    .get("label")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                language: String::new(),
                is_default: t.get("default") == Some(&Value::Bool(true)),
            });
        }
    }

    Ok(Some(StreamResultOut {
        url: file.to_string(),
        referer: format!("{origin}/"),
        origin,
        tracks,
        provider: String::new(),
        stream_label: None,
    }))
}
