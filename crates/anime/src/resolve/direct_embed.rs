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

    let (play_referer, play_origin) = stream_playback_headers(file, &origin);
    Ok(Some(StreamResultOut {
        url: file.to_string(),
        referer: play_referer,
        origin: play_origin,
        tracks,
        provider: String::new(),
        stream_label: None,
    }))
}

/// CDN hosts rotate (nekostream, mewstream, …). Self-origin / scrape Referer
/// → 403; force the embed family host used by the player header rewrite.
fn stream_playback_headers(file: &str, embed_origin: &str) -> (String, String) {
    let host = file
        .strip_prefix("https://")
        .or_else(|| file.strip_prefix("http://"))
        .and_then(|rest| rest.split('/').next())
        .unwrap_or("")
        .to_lowercase();
    if host.contains("mewstream")
        || host.contains("nekostream")
        || host.contains("lostproject")
        || host.contains("megaplay")
    {
        return (
            "https://megaplay.buzz/".into(),
            "https://megaplay.buzz".into(),
        );
    }
    if host.contains("watching.onl") || host.contains("vidwish") {
        return (
            "https://vidwish.live/".into(),
            "https://vidwish.live".into(),
        );
    }
    (format!("{embed_origin}/"), embed_origin.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nekostream_file_forces_megaplay_referer() {
        let (r, o) = stream_playback_headers(
            "https://9hjkrt.nekostream.site/a/b/master.m3u8",
            "https://megaplay.buzz",
        );
        assert!(r.contains("megaplay.buzz"));
        assert!(o.contains("megaplay.buzz"));
    }
}
