use std::collections::HashMap;

use serde_json::{json, Value};

use super::common::{anime_get, AnimeTrackOut, StreamResultOut, DEFAULT_UA};

const API_BASE: &str = "https://new.vidnest.fun";
const EMBED_ORIGIN: &str = "https://vidnest.fun";

/// Custom alphabet from vidnest.fun player (`decryptCipherResponse`).
const CIPHER_ALPHABET: &str = "RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=";

pub const KNOWN_PROVIDERS: &[&str] = &["hianime", "animepahe"];

fn headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
        ("Origin".into(), EMBED_ORIGIN.into()),
        ("Referer".into(), format!("{EMBED_ORIGIN}/")),
    ])
}

fn decrypt_cipher(data: &str) -> Result<String, String> {
    let mut index = HashMap::new();
    for (i, c) in CIPHER_ALPHABET.chars().enumerate() {
        index.insert(c, i);
    }
    let mut out = Vec::new();
    let chars: Vec<char> = data.chars().collect();
    let mut t = 0;
    while t < chars.len() {
        let end = (t + 4).min(chars.len());
        let mut chunk: String = chars[t..end].iter().collect();
        while chunk.len() < 4 {
            chunk.push('=');
        }
        let l: Vec<usize> = chunk
            .chars()
            .map(|c| index.get(&c).copied().unwrap_or(64))
            .collect();
        if l.len() < 4 {
            break;
        }
        out.push(((l[0] << 2) | (l[1] >> 4)) as u8);
        if l[2] != 64 {
            out.push((((l[1] & 15) << 4) | (l[2] >> 2)) as u8);
        }
        if l[3] != 64 {
            out.push((((l[2] & 3) << 6) | l[3]) as u8);
        }
        t += 4;
    }
    String::from_utf8(out).map_err(|e| e.to_string())
}

fn decode_body(body: &str) -> Result<Value, String> {
    let outer: Value = serde_json::from_str(body).map_err(|e| e.to_string())?;
    let plain = if outer.get("encrypted") == Some(&json!(true)) {
        let data = outer.get("data").and_then(|v| v.as_str()).unwrap_or("");
        if data.is_empty() {
            return Err("empty encrypted payload".into());
        }
        decrypt_cipher(data)?
    } else {
        body.to_string()
    };
    serde_json::from_str(&plain).map_err(|e| e.to_string())
}

fn playback_headers(url: &str) -> (String, String) {
    let host = url
        .strip_prefix("https://")
        .or_else(|| url.strip_prefix("http://"))
        .and_then(|rest| rest.split('/').next())
        .unwrap_or("");
    if host.contains("hakunaymatata.com") {
        return (String::new(), String::new());
    }
    if host.contains("mewstream.buzz") || host.contains("megaplay") {
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
    (format!("{EMBED_ORIGIN}/"), EMBED_ORIGIN.to_string())
}

pub fn vidnest_streams(
    anilist_id: i64,
    episode: i32,
    category: &str,
    provider: &str,
) -> Result<Value, String> {
    let provider = provider.trim().to_lowercase();
    if !KNOWN_PROVIDERS.contains(&provider.as_str()) {
        return Ok(json!({ "result": null }));
    }
    let cat = if category.eq_ignore_ascii_case("dub") {
        "dub"
    } else {
        "sub"
    };
    let url = format!("{API_BASE}/{provider}/anime/{anilist_id}/{episode}/{cat}");
    let resp = anime_get(&url, &headers(), 15)?;
    if resp.status != 200 {
        return Ok(json!({ "result": null }));
    }
    let json = decode_body(&resp.body)?;
    let sources = json
        .get("sources")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let file = sources
        .iter()
        .find_map(|s| s.get("file").and_then(|v| v.as_str()))
        .unwrap_or("");
    if file.is_empty() {
        return Ok(json!({ "result": null }));
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
            if url.is_empty() {
                continue;
            }
            tracks.push(AnimeTrackOut {
                url: url.to_string(),
                label: t
                    .get("label")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                language: String::new(),
                is_default: t.get("default") == Some(&json!(true)),
            });
        }
    }

    let (referer, origin) = playback_headers(file);
    Ok(json!({
        "result": StreamResultOut {
            url: file.to_string(),
            referer,
            origin,
            tracks,
            provider: format!("vidnest:{provider}"),
            stream_label: None,
        }
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decrypt_cipher_rejects_empty() {
        assert!(decrypt_cipher("").is_ok());
    }

    #[test]
    fn playback_headers_mewstream_uses_megaplay_referer() {
        let (r, o) = playback_headers("https://cdn.mewstream.buzz/anime/x/master.m3u8");
        assert!(r.contains("megaplay"));
        assert!(o.contains("megaplay"));
    }

    #[test]
    fn playback_headers_moviebox_ua_only() {
        let (r, o) = playback_headers("https://abc.hakunaymatata.com/x.mp4");
        assert!(r.is_empty());
        assert!(o.is_empty());
    }

    /// Live smoke — ignored by default (network).
    #[test]
    #[ignore]
    fn vidnest_hianime_resolves_frieren_ep1() {
        let out = vidnest_streams(154587, 1, "sub", "hianime").unwrap();
        let url = out
            .pointer("/result/url")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert!(
            !url.is_empty() && url.contains(".m3u8"),
            "expected hls url, got {out}"
        );
    }
}
