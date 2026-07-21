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

    // Megaplay/Vidwish embed HTML often returns 410 without `data-id`, while
    // `/stream/getSources?id={catalogId}` still serves the file. Prefer the
    // `/stream/s-2/{id}/…` path id — skip the dead page scrape.
    let data_id = match catalog_id_from_embed_url(embed_url) {
        Some(id) => id,
        None => match scrape_data_id(embed_url, referer) {
            Ok(Some(id)) => id,
            Ok(None) => return Ok(None),
            Err(e) => return Err(e),
        },
    };
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

    let Ok(api) = anime_get(&api_url, &api_headers, 15) else {
        return Ok(None);
    };
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

/// Anikoto / HiAnime catalog episode id from `/stream/s-2/{id}/{lang}`.
fn catalog_id_from_embed_url(embed_url: &str) -> Option<String> {
    let re = Regex::new(r"/stream/s-2/(\d+)(?:/|\?|$)").ok()?;
    re.captures(embed_url)?
        .get(1)
        .map(|m| m.as_str().to_string())
}

fn scrape_data_id(embed_url: &str, referer: &str) -> Result<Option<String>, String> {
    let page_headers = HashMap::from([
        ("Referer".into(), referer.into()),
        ("User-Agent".into(), DEFAULT_UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
        ),
    ]);

    // Transport / soft-404 / missing player → None (race tries next host).
    let Ok(page) = anime_get(embed_url, &page_headers, 15) else {
        return Ok(None);
    };
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
    Ok(Some(data_id.to_string()))
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
        // VidTube embeds also land on nekostream — keep the embed origin Referer.
        if embed_origin.to_lowercase().contains("vidtube") {
            let o = embed_origin.trim_end_matches('/').to_string();
            return (format!("{o}/"), o);
        }
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
    if host.contains("vidtube") {
        return (
            "https://vidtube.site/".into(),
            "https://vidtube.site".into(),
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

    #[test]
    fn catalog_id_from_s2_path() {
        assert_eq!(
            catalog_id_from_embed_url(
                "https://megaplay.buzz/stream/s-2/128368/sub?autoPlay=1"
            )
            .as_deref(),
            Some("128368")
        );
        assert_eq!(
            catalog_id_from_embed_url("https://vidwish.live/stream/s-2/99/dub").as_deref(),
            Some("99")
        );
        assert!(
            catalog_id_from_embed_url("https://megaplay.buzz/stream/ani/171018/1/sub").is_none()
        );
    }

    #[test]
    #[ignore = "network — Megaplay getSources via s-2 id (HTML may be 410)"]
    fn s2_catalog_id_get_sources_without_html() {
        let out = direct_embed_extract(
            "https://megaplay.buzz/stream/s-2/128368/sub",
            Some("https://www.enma.lol/"),
        )
        .expect("extract");
        let hit = out.expect("stream");
        assert!(hit.url.contains("m3u8") || hit.url.contains("nekostream") || !hit.url.is_empty());
        assert!(hit.referer.contains("megaplay"));
    }
}
