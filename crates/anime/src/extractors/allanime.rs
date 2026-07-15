use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use aes::Aes256;
use base64::Engine;
use ctr::cipher::{KeyIvInit, StreamCipher};
use ctr::Ctr128BE;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

use super::common::{anime_get, anime_post, AnimeTrackOut, StreamResultOut};

type CtrCipher = Ctr128BE<Aes256>;

const API: &str = "https://api.allanime.day/api";
const REFR: &str = "https://allmanga.to";
const YT_CHAN: &str = "https://youtu-chan.com";
const CLOCK_HOST: &str = "https://allanime.day";
const AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0";
const EPISODE_QUERY_HASH: &str = "d405d0edd690624b66baba3068e0edc3ac90f1597d898a1ec8db4e5c43c00fec";

const SEARCH_GQL: &str = r#"query($search: SearchInput $limit: Int $page: Int $translationType: VaildTranslationTypeEnumType $countryOrigin: VaildCountryOriginEnumType) { shows(search: $search limit: $limit page: $page translationType: $translationType countryOrigin: $countryOrigin) { edges { _id name englishName availableEpisodes __typename } } }"#;

/// Upstream `sourceName` values we expose in Settings / the Source panel.
///
/// `Default` is a Forja alias (not an AllAnime name) that tries the strongest
/// live sources in order. `Uv-mp4` was removed — AllAnime no longer returns it.
pub const KNOWN_PROVIDERS: &[&str] = &["Default", "Yt-mp4", "S-mp4", "Luf-Mp4"];

/// Preference order when resolving `Default` or when a named source misses.
const DEFAULT_TRY_ORDER: &[&str] = &["Yt-mp4", "S-mp4", "Luf-Mp4"];

static SHOW_ID_CACHE: OnceLock<Mutex<HashMap<String, String>>> = OnceLock::new();
static SOURCES_CACHE: OnceLock<Mutex<HashMap<String, Vec<Value>>>> = OnceLock::new();

fn show_cache() -> &'static Mutex<HashMap<String, String>> {
    SHOW_ID_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn sources_cache() -> &'static Mutex<HashMap<String, Vec<Value>>> {
    SOURCES_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn aes_key() -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(b"Xot36i3lK3:v1");
    hasher.finalize().into()
}

pub fn decrypt_tobeparsed(blob: &str) -> Option<String> {
    let raw = base64::engine::general_purpose::STANDARD
        .decode(blob)
        .ok()?;
    if raw.len() < 13 + 16 {
        return None;
    }
    let mut iv = [0u8; 16];
    for i in 0..12 {
        iv[i] = raw[1 + i];
    }
    iv[15] = 2;

    let ct_len = raw.len().saturating_sub(13 + 16);
    if ct_len == 0 {
        return None;
    }
    let mut ct = raw[13..13 + ct_len].to_vec();

    let mut cipher = CtrCipher::new(&aes_key().into(), &iv.into());
    cipher.apply_keystream(&mut ct);
    String::from_utf8(ct).ok()
}

fn decode_xor_path(raw: &str) -> Option<String> {
    let s = raw.strip_prefix("--").unwrap_or(raw);
    if s.len() < 2 || !s.len().is_multiple_of(2) {
        return None;
    }
    let mut out = String::new();
    let bytes = s.as_bytes();
    for chunk in bytes.chunks(2) {
        let hex = std::str::from_utf8(chunk).ok()?;
        let byte = u8::from_str_radix(hex, 16).ok()?;
        out.push((byte ^ 0x38) as char);
    }
    Some(out)
}

fn post_headers(refr: &str) -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), AGENT.into()),
        ("Referer".into(), refr.into()),
        ("Origin".into(), refr.into()),
        ("Content-Type".into(), "application/json".into()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
    ])
}

fn get_headers(refr: &str, origin: &str) -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), AGENT.into()),
        ("Referer".into(), refr.into()),
        ("Origin".into(), origin.into()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
    ])
}

fn search_one(query: &str, cat: &str) -> Result<Option<String>, String> {
    let body = json!({
        "variables": {
            "search": {
                "allowAdult": false,
                "allowUnknown": false,
                "query": query,
            },
            "limit": 40,
            "page": 1,
            "translationType": if cat == "dub" { "dub" } else { "sub" },
            "countryOrigin": "ALL",
        },
        "query": SEARCH_GQL,
    });
    let resp = anime_post(API, &post_headers(REFR), &body.to_string(), 15)?;
    if resp.status != 200 {
        return Ok(None);
    }
    let json: Value = serde_json::from_str(&resp.body).map_err(|e| e.to_string())?;
    let edges = json
        .pointer("/data/shows/edges")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    if edges.is_empty() {
        return Ok(None);
    }
    let q_lower = query.to_lowercase();
    let mut best = edges.first().cloned();
    for e in &edges {
        let name = e
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        let eng = e
            .get("englishName")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        if name == q_lower || eng == q_lower {
            best = Some(e.clone());
            break;
        }
    }
    if let Some(e) = best {
        return Ok(e.get("_id").and_then(|v| v.as_str()).map(str::to_string));
    }
    Ok(None)
}

pub fn allanime_search(title_candidates: &[String], category: &str) -> Result<Value, String> {
    let key = format!("{category}|{}", title_candidates.join("|"));
    if let Ok(cache) = show_cache().lock() {
        if let Some(id) = cache.get(&key) {
            return Ok(json!({ "show_id": id }));
        }
    }
    for raw in title_candidates {
        let t = raw.trim();
        if t.is_empty() {
            continue;
        }
        if let Some(id) = search_one(t, category)? {
            if let Ok(mut cache) = show_cache().lock() {
                cache.insert(key, id.clone());
            }
            return Ok(json!({ "show_id": id }));
        }
    }
    Ok(json!({ "show_id": null }))
}

fn episode_sources(show_id: &str, episode: i32, cat: &str) -> Result<Vec<Value>, String> {
    let key = format!("{show_id}|{episode}|{cat}");
    if let Ok(cache) = sources_cache().lock() {
        if let Some(s) = cache.get(&key) {
            return Ok(s.clone());
        }
    }

    let vars = json!({
        "showId": show_id,
        "translationType": if cat == "dub" { "dub" } else { "sub" },
        "episodeString": format!("{episode}"),
    });
    let ext = json!({
        "persistedQuery": {
            "version": 1,
            "sha256Hash": EPISODE_QUERY_HASH,
        }
    });
    let url = format!(
        "{API}?variables={}&extensions={}",
        urlencoding::encode(&vars.to_string()),
        urlencoding::encode(&ext.to_string())
    );
    let resp = anime_get(&url, &get_headers(YT_CHAN, YT_CHAN), 15)?;
    if resp.status != 200 {
        return Ok(vec![]);
    }
    let json: Value = serde_json::from_str(&resp.body).map_err(|e| e.to_string())?;

    let episode_data = if let Some(blob) = json.pointer("/data/tobeparsed").and_then(|v| v.as_str())
    {
        if blob.is_empty() {
            None
        } else {
            let plain = decrypt_tobeparsed(blob).ok_or_else(|| "decrypt failed".to_string())?;
            let decoded: Value = serde_json::from_str(&plain).map_err(|e| e.to_string())?;
            decoded.get("episode").cloned()
        }
    } else {
        json.pointer("/data/episode").cloned()
    };

    let list = episode_data
        .and_then(|e| e.get("sourceUrls").cloned())
        .and_then(|v| v.as_array().cloned())
        .unwrap_or_default();

    if let Ok(mut cache) = sources_cache().lock() {
        cache.insert(key, list.clone());
    }
    Ok(list)
}

fn resolve_decoded_path(path: &str, provider: &str) -> Result<Option<StreamResultOut>, String> {
    let mut p = path.to_string();
    if p.contains("/clock?") && !p.contains("/clock.json?") {
        p = p.replace("/clock?", "/clock.json?");
    }
    let uri = if p.starts_with("http") {
        p
    } else {
        format!("{CLOCK_HOST}{p}")
    };

    let resp = anime_get(&uri, &get_headers(&format!("{REFR}/"), REFR), 15)?;
    if resp.status != 200 {
        return Ok(None);
    }
    let json: Value = serde_json::from_str(&resp.body).map_err(|e| e.to_string())?;
    let links = json
        .get("links")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    if links.is_empty() {
        return Ok(None);
    }

    let mut hls: Option<&Value> = None;
    let mut mp4: Option<&Value> = None;
    for l in &links {
        let link = l.get("link").and_then(|v| v.as_str()).unwrap_or("");
        if link.is_empty() {
            continue;
        }
        let is_hls =
            l.get("hls") == Some(&Value::Bool(true)) || link.to_lowercase().contains(".m3u8");
        let is_mp4 =
            l.get("mp4") == Some(&Value::Bool(true)) || link.to_lowercase().contains(".mp4");
        if is_hls && hls.is_none() {
            hls = Some(l);
        }
        if is_mp4 && mp4.is_none() {
            mp4 = Some(l);
        }
    }
    let pick = hls.or(mp4).or_else(|| links.first());

    let pick = match pick {
        Some(v) => v,
        None => return Ok(None),
    };
    let url = pick.get("link").and_then(|v| v.as_str()).unwrap_or("");
    if url.is_empty() {
        return Ok(None);
    }

    let mut tracks = Vec::new();
    if let Some(subs) = pick.get("subtitles").and_then(|v| v.as_array()) {
        for t in subs {
            let f = t
                .get("src")
                .or_else(|| t.get("file"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if f.is_empty() {
                continue;
            }
            let default = matches!(t.get("default"), Some(Value::Bool(true)))
                || t.get("default").and_then(|v| v.as_str()) == Some("default");
            tracks.push(AnimeTrackOut {
                url: f.to_string(),
                label: t
                    .get("label")
                    .or_else(|| t.get("lang"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                language: String::new(),
                is_default: default,
            });
        }
    }

    let referer = pick
        .get("Referer")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(&format!("{REFR}/"))
        .to_string();
    let origin = referer
        .strip_prefix("https://")
        .and_then(|s| s.split('/').next())
        .map(|h| format!("https://{h}"))
        .unwrap_or_else(|| REFR.to_string());

    Ok(Some(StreamResultOut {
        url: url.to_string(),
        referer,
        origin,
        tracks,
        provider: provider.to_string(),
        stream_label: None,
    }))
}

fn is_iframe_embed_url(url: &str) -> bool {
    let u = url.to_lowercase();
    u.contains("/embed")
        || u.contains("ok.ru/")
        || u.contains("streamwish.")
        || u.contains("mp4upload.")
        || u.contains("bysekoze.")
        || u.contains("uns.bio")
        || u.contains("strmup.")
        || u.contains("vidmoly.")
        || u.contains("filemoon.")
}

fn resolve_source_url(raw: &str, provider_label: &str) -> Result<Option<StreamResultOut>, String> {
    let raw = raw.trim();
    if raw.is_empty() {
        return Ok(None);
    }
    if raw.starts_with("--") {
        if let Some(decoded) = decode_xor_path(raw) {
            return resolve_decoded_path(&decoded, provider_label);
        }
        return Ok(None);
    }
    // Direct CDN / MP4 hosts (e.g. Yt-mp4 on tools.fast4speed.rsvp).
    // AllAnime also returns iframe players we cannot play — skip those.
    if raw.starts_with("http") && !is_iframe_embed_url(raw) {
        return Ok(Some(StreamResultOut {
            url: raw.to_string(),
            referer: format!("{REFR}/"),
            origin: REFR.to_string(),
            tracks: Vec::new(),
            provider: provider_label.to_string(),
            stream_label: None,
        }));
    }
    Ok(None)
}

fn try_resolve_named_source(
    sources: &[Value],
    wanted_name: &str,
    provider_label: &str,
) -> Result<Option<StreamResultOut>, String> {
    let wanted = wanted_name.to_lowercase();
    for src in sources {
        let name = src
            .get("sourceName")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_lowercase();
        if name != wanted {
            continue;
        }
        let raw = src.get("sourceUrl").and_then(|v| v.as_str()).unwrap_or("");
        if let Some(result) = resolve_source_url(raw, provider_label)? {
            return Ok(Some(result));
        }
    }
    Ok(None)
}

pub fn allanime_sources(
    title_candidates: &[String],
    episode: i32,
    category: &str,
    provider: &str,
) -> Result<Value, String> {
    let search = allanime_search(title_candidates, category)?;
    let show_id = match search.get("show_id").and_then(|v| v.as_str()) {
        Some(id) if !id.is_empty() => id.to_string(),
        _ => return Ok(json!({ "result": null })),
    };

    let sources = episode_sources(&show_id, episode, category)?;
    if sources.is_empty() {
        return Ok(json!({ "result": null }));
    }

    let wanted = provider.trim();
    if wanted.eq_ignore_ascii_case("Default") {
        for name in DEFAULT_TRY_ORDER {
            if let Some(result) = try_resolve_named_source(&sources, name, "Default")? {
                return Ok(json!({ "result": result }));
            }
        }
        // Last resort: any non-iframe http / any -- clock path still present.
        for src in &sources {
            let raw = src.get("sourceUrl").and_then(|v| v.as_str()).unwrap_or("");
            let label = src
                .get("sourceName")
                .and_then(|v| v.as_str())
                .unwrap_or("Default");
            if let Some(result) = resolve_source_url(raw, label)? {
                return Ok(json!({ "result": result }));
            }
        }
        return Ok(json!({ "result": null }));
    }

    if let Some(result) = try_resolve_named_source(&sources, wanted, wanted)? {
        return Ok(json!({ "result": result }));
    }
    Ok(json!({ "result": null }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decode_xor_path_roundtrip() {
        let path = "/apivtwo/clock?id=123";
        let hex: String = path.bytes().map(|b| format!("{:02x}", b ^ 0x38)).collect();
        let decoded = decode_xor_path(&format!("--{hex}")).unwrap();
        assert_eq!(decoded, path);
    }

    #[test]
    fn decrypt_tobeparsed_rejects_short_blob() {
        let b64 = base64::engine::general_purpose::STANDARD.encode([0u8; 20]);
        assert!(decrypt_tobeparsed(&b64).is_none());
    }

    #[test]
    fn is_iframe_embed_url_detects_players() {
        assert!(is_iframe_embed_url("https://ok.ru/videoembed/1"));
        assert!(is_iframe_embed_url("https://streamwish.to/e/abc"));
        assert!(!is_iframe_embed_url(
            "https://tools.fast4speed.rsvp/media9/videos/x/sub/1?Authorization=1"
        ));
    }

    #[test]
    fn resolve_source_url_accepts_direct_http() {
        let url = "https://tools.fast4speed.rsvp/media9/videos/x/sub/1?Authorization=1";
        let out = resolve_source_url(url, "Yt-mp4").unwrap().unwrap();
        assert_eq!(out.url, url);
        assert!(out.referer.contains("allmanga.to"));
    }

    #[test]
    fn resolve_source_url_skips_iframe() {
        assert!(resolve_source_url("https://ok.ru/videoembed/1", "Ok")
            .unwrap()
            .is_none());
    }

    /// Live smoke — ignored by default (network).
    #[test]
    #[ignore]
    fn allanime_default_resolves_frieren_ep1() {
        let titles = vec![
            "Frieren: Beyond Journey's End".into(),
            "Sousou no Frieren".into(),
        ];
        let out = allanime_sources(&titles, 1, "sub", "Default").unwrap();
        let url = out
            .pointer("/result/url")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        assert!(
            !url.is_empty() && url.starts_with("http"),
            "expected playable url, got {out}"
        );
    }
}
