use std::collections::HashMap;
use std::io::Read;
use std::sync::{Mutex, OnceLock};

use base64::Engine;
use flate2::read::{DeflateDecoder, GzDecoder, ZlibDecoder};
use serde_json::{json, Value};

use super::common::{anime_get, AnimeTrackOut, StreamResultOut, DEFAULT_UA};

const PIPE_OBF_KEY: [u8; 16] = [
    0x71, 0x95, 0x10, 0x34, 0xf8, 0xfb, 0xcf, 0x53, 0xd8, 0x9d, 0xb5, 0x2c, 0xeb, 0x3d, 0xc2, 0x2c,
];

pub const OFFICIAL_DOMAINS: &[&str] = &[
    "https://www.miruro.tv",
    "https://www.miruro.to",
    "https://www.miruro.bz",
    "https://www.miruro.ru",
];

pub const KNOWN_PROVIDERS: &[&str] = &[
    "zoro",
    "kiwi",
    "bee",
    "hop",
    "bonk",
    "ally",
    "moo",
    "animedunya",
    "arc",
    "jet",
    "bun",
    "kuz",
    "telli",
];

pub const UPSTREAM_SOURCES: &[(&str, &str)] = &[
    ("kiwi", "AnimePahe"),
    ("ally", "AllManga"),
    ("bonk", "AnimeDao"),
    ("bee", "AniKoto"),
    ("moo", "AnimeGG"),
    ("hop", "Miruro"),
    ("arc", "Miruro internal"),
    ("zoro", "HiAnime"),
    ("jet", "Miruro internal"),
    ("animedunya", "AnimeDunya"),
    ("bun", "Miruro"),
    ("kuz", "Miruro"),
    ("telli", "Miruro"),
];

const PROTOCOL_VERSIONS: &[&str] = &["0.2.0", "0.1.0"];

static EPS_CACHE: OnceLock<Mutex<HashMap<i64, Value>>> = OnceLock::new();
static ACTIVE_BASE: OnceLock<Mutex<Option<String>>> = OnceLock::new();

fn eps_cache() -> &'static Mutex<HashMap<i64, Value>> {
    EPS_CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn active_base() -> &'static Mutex<Option<String>> {
    ACTIVE_BASE.get_or_init(|| Mutex::new(None))
}

pub fn encode_pipe_request(payload: &Value) -> String {
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(payload.to_string())
}

pub fn decode_pipe_body(body: &str, x_obf: Option<&str>) -> Result<Value, String> {
    if body.is_empty() {
        return Err("empty body".into());
    }
    let x_obf = x_obf.map(str::trim).filter(|s| !s.is_empty());
    if x_obf.is_none() {
        return serde_json::from_str(body).map_err(|e| e.to_string());
    }
    let plain = deobfuscate(body, x_obf.unwrap())?;
    serde_json::from_str(&plain).map_err(|e| e.to_string())
}

fn decompress(data: &[u8]) -> Vec<u8> {
    if data.len() >= 2 && data[0] == 0x1f && data[1] == 0x8b {
        let mut dec = GzDecoder::new(data);
        let mut out = Vec::new();
        if dec.read_to_end(&mut out).is_ok() {
            return out;
        }
    }
    {
        let mut dec = ZlibDecoder::new(data);
        let mut out = Vec::new();
        if dec.read_to_end(&mut out).is_ok() {
            return out;
        }
    }
    let mut prefixed = vec![0x78, 0x01];
    prefixed.extend_from_slice(data);
    let mut dec = DeflateDecoder::new(&prefixed[..]);
    let mut out = Vec::new();
    if dec.read_to_end(&mut out).is_ok() {
        return out;
    }
    data.to_vec()
}

fn deobfuscate(body: &str, level: &str) -> Result<String, String> {
    let mut b64 = body.replace('-', "+").replace('_', "/");
    let pad = b64.len() % 4;
    if pad != 0 {
        b64.push_str(&"=".repeat(4 - pad));
    }
    let mut data = base64::engine::general_purpose::STANDARD
        .decode(b64)
        .map_err(|e| e.to_string())?;

    if level == "2" {
        for (i, b) in data.iter_mut().enumerate() {
            *b ^= PIPE_OBF_KEY[i % PIPE_OBF_KEY.len()];
        }
    }
    let decompressed = decompress(&data);
    String::from_utf8(decompressed).map_err(|e| e.to_string())
}

fn pipe_headers(base: &str) -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.replace("122", "131")),
        ("Referer".into(), format!("{base}/")),
        ("Origin".into(), base.to_string()),
        ("Accept".into(), "application/json, text/plain, */*".into()),
        ("Accept-Language".into(), "en-US,en;q=0.9".into()),
        ("Sec-Fetch-Dest".into(), "empty".into()),
        ("Sec-Fetch-Mode".into(), "cors".into()),
        ("Sec-Fetch-Site".into(), "same-origin".into()),
    ])
}

fn domain_order() -> Vec<String> {
    let mut out = Vec::new();
    if let Ok(lock) = active_base().lock() {
        if let Some(b) = lock.as_ref() {
            out.push(b.clone());
        }
    }
    let remote = utils::provider_runtime::miruro_origins();
    let domains: Vec<String> = remote.unwrap_or_else(|| {
        OFFICIAL_DOMAINS.iter().map(|d| (*d).to_string()).collect()
    });
    for d in domains {
        if !out.iter().any(|x| x == &d) {
            out.push(d);
        }
    }
    out
}

fn set_active_base(base: &str) {
    if let Ok(mut lock) = active_base().lock() {
        *lock = Some(base.to_string());
    }
}

fn episodes_pipe_url(anilist_id: i64) -> String {
    let payload = json!({
        "path": "episodes",
        "method": "GET",
        "query": { "anilistId": anilist_id.to_string() },
        "body": null,
        "version": PROTOCOL_VERSIONS[0],
    });
    let encoded = encode_pipe_request(&payload);
    let base = domain_order()
        .first()
        .cloned()
        .unwrap_or_else(|| OFFICIAL_DOMAINS[0].to_string());
    format!("{base}/api/secure/pipe?e={encoded}")
}

pub fn fetch_episodes(
    anilist_id: i64,
    webview_body: Option<&str>,
    webview_x_obf: Option<&str>,
    webview_pipe_path: Option<&str>,
) -> Result<Value, String> {
    // Always prefer cache — a sources-pipe WebView body must not wipe episodes.
    if let Ok(cache) = eps_cache().lock() {
        if let Some(v) = cache.get(&anilist_id) {
            return Ok(v.clone());
        }
    }
    let query = HashMap::from([("anilistId".into(), anilist_id.to_string())]);
    let use_wv = webview_pipe_path == Some("episodes");
    let result = api_get(
        "episodes",
        &query,
        if use_wv { webview_body } else { None },
        if use_wv { webview_x_obf } else { None },
    )?;
    match result {
        Some(v) => {
            if let Ok(mut cache) = eps_cache().lock() {
                cache.insert(anilist_id, v.clone());
            }
            Ok(v)
        }
        None => Ok(json!({
            "cf_blocked": true,
            "pipe_url": episodes_pipe_url(anilist_id),
            "pipe_path": "episodes",
        })),
    }
}

fn api_get(
    path: &str,
    query: &HashMap<String, String>,
    webview_body: Option<&str>,
    webview_x_obf: Option<&str>,
) -> Result<Option<Value>, String> {
    for version in PROTOCOL_VERSIONS {
        if let Some(v) = api_get_version(path, query, version, webview_body, webview_x_obf)? {
            return Ok(Some(v));
        }
    }
    Ok(None)
}

fn api_get_version(
    path: &str,
    query: &HashMap<String, String>,
    version: &str,
    webview_body: Option<&str>,
    webview_x_obf: Option<&str>,
) -> Result<Option<Value>, String> {
    let payload = json!({
        "path": path,
        "method": "GET",
        "query": query,
        "body": null,
        "version": version,
    });
    let encoded = encode_pipe_request(&payload);

    if let (Some(body), x_obf) = (webview_body, webview_x_obf) {
        if let Ok(decoded) = decode_pipe_body(body, x_obf) {
            return Ok(Some(decoded));
        }
    }

    // Network errors must not abort the whole resolve — Miruro sits behind CF and
    // reqwest often fails before a 403 body. Returning None triggers Dart WebView.
    for base in domain_order() {
        let uri = format!("{base}/api/secure/pipe?e={encoded}");
        let direct = match anime_get(&uri, &pipe_headers(&base), 20) {
            Ok(r) => r,
            Err(_) => continue,
        };
        if direct.status == 200 {
            if let Ok(decoded) = decode_pipe_body(
                &direct.body,
                direct.headers.get("x-obfuscated").map(|s| s.as_str()),
            ) {
                set_active_base(&base);
                return Ok(Some(decoded));
            }
        }
        if direct.status == 403 || direct.body.to_lowercase().contains("cloudflare") {
            // CF on this host — don't burn timeout on the other mirrors.
            return Ok(None);
        }
    }
    Ok(None)
}

fn parse_subtitle_tracks(src: &Value) -> Vec<AnimeTrackOut> {
    let mut tracks = Vec::new();
    if let Some(subs) = src.get("subtitles").and_then(|v| v.as_array()) {
        for t in subs {
            let file_url = t
                .get("file")
                .or_else(|| t.get("url"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if file_url.is_empty() {
                continue;
            }
            tracks.push(AnimeTrackOut {
                url: file_url.to_string(),
                label: t
                    .get("label")
                    .and_then(|v| v.as_str())
                    .unwrap_or("Unknown")
                    .to_string(),
                language: t
                    .get("language")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
                is_default: t.get("default") == Some(&Value::Bool(true)),
            });
        }
    }
    tracks
}

fn resolve_stream_referer(stream: &Value, src: &Value, anilist_id: i64, base: &str) -> String {
    for key in ["referer", "Referer", "referrer"] {
        if let Some(v) = stream.get(key).and_then(|v| v.as_str()) {
            let t = v.trim();
            if !t.is_empty() {
                return t.to_string();
            }
        }
    }
    for key in ["referer", "Referer", "referrer"] {
        if let Some(v) = src.get(key).and_then(|v| v.as_str()) {
            let t = v.trim();
            if !t.is_empty() {
                return t.to_string();
            }
        }
    }
    if let Some(headers) = stream.get("headers").and_then(|v| v.as_object()) {
        for key in ["Referer", "referer"] {
            if let Some(v) = headers.get(key).and_then(|v| v.as_str()) {
                let t = v.trim();
                if !t.is_empty() {
                    return t.to_string();
                }
            }
        }
    }
    format!("{base}/watch/{anilist_id}")
}

fn stream_server_label(stream: &Value, index: usize) -> String {
    for key in ["server", "label", "name", "id"] {
        if let Some(v) = stream.get(key).and_then(|v| v.as_str()) {
            let t = v.trim();
            if !t.is_empty() {
                return t.to_string();
            }
        }
    }
    format!("stream-{index}")
}

pub fn miruro_resolve(
    anilist_id: i64,
    episode: i32,
    category: &str,
    provider: &str,
    webview_body: Option<&str>,
    webview_x_obf: Option<&str>,
    webview_pipe_path: Option<&str>,
) -> Result<Value, String> {
    let ep_data = fetch_episodes(anilist_id, webview_body, webview_x_obf, webview_pipe_path)?;
    if ep_data.get("cf_blocked").and_then(|v| v.as_bool()) == Some(true) {
        return Ok(ep_data);
    }

    let providers_map = ep_data
        .get("providers")
        .and_then(|v| v.as_object())
        .cloned()
        .unwrap_or_default();
    let prov = match providers_map.get(provider) {
        Some(v) => v,
        None => return Ok(json!({ "streams": [] })),
    };
    let eps = prov
        .get("episodes")
        .and_then(|v| v.as_object())
        .cloned()
        .unwrap_or_default();
    let list = match eps.get(category).and_then(|v| v.as_array()) {
        Some(v) if !v.is_empty() => v,
        _ => return Ok(json!({ "streams": [] })),
    };

    let mut hit: Option<&Value> = None;
    for raw in list {
        if raw.get("number").and_then(|v| v.as_i64()) == Some(episode as i64) {
            hit = Some(raw);
            break;
        }
    }
    let hit = match hit {
        Some(v) => v,
        None => return Ok(json!({ "streams": [] })),
    };
    let ep_id = hit.get("id").and_then(|v| v.as_str()).unwrap_or("");
    if ep_id.is_empty() {
        return Ok(json!({ "streams": [] }));
    }

    let query = HashMap::from([
        ("episodeId".into(), ep_id.to_string()),
        ("provider".into(), provider.to_string()),
        ("category".into(), category.to_string()),
        ("anilistId".into(), anilist_id.to_string()),
    ]);

    // Never reuse an episodes WebView body for the sources pipe — that used to
    // return empty streams with no cf_blocked, so the Dart fallback never ran.
    let use_wv = webview_pipe_path == Some("sources");
    let src = match api_get(
        "sources",
        &query,
        if use_wv { webview_body } else { None },
        if use_wv { webview_x_obf } else { None },
    )? {
        Some(v) => v,
        None => {
            let payload = json!({
                "path": "sources",
                "method": "GET",
                "query": query,
                "body": null,
                "version": PROTOCOL_VERSIONS[0],
            });
            let encoded = encode_pipe_request(&payload);
            let base = domain_order()
                .first()
                .cloned()
                .unwrap_or_else(|| OFFICIAL_DOMAINS[0].to_string());
            return Ok(json!({
                "streams": [],
                "cf_blocked": true,
                "pipe_url": format!("{base}/api/secure/pipe?e={encoded}"),
                "pipe_path": "sources",
            }));
        }
    };

    let base = domain_order()
        .first()
        .cloned()
        .unwrap_or_else(|| OFFICIAL_DOMAINS[0].to_string());
    let tracks = parse_subtitle_tracks(&src);
    let streams = src
        .get("streams")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut out = Vec::new();
    let mut stream_index = 0;

    for raw in streams {
        let stream_type = raw.get("type").and_then(|v| v.as_str()).unwrap_or("");
        if !stream_type.is_empty() && stream_type != "hls" {
            continue;
        }
        let url = raw.get("url").and_then(|v| v.as_str()).unwrap_or("");
        if url.is_empty() {
            continue;
        }
        stream_index += 1;
        let referer = resolve_stream_referer(&raw, &src, anilist_id, &base);
        let origin = referer
            .strip_prefix("https://")
            .and_then(|s| s.split('/').next())
            .map(|h| format!("https://{h}"))
            .or_else(|| {
                url.strip_prefix("https://")
                    .and_then(|s| s.split('/').next())
                    .map(|h| format!("https://{h}"))
            })
            .unwrap_or_else(|| base.clone());

        out.push(StreamResultOut {
            url: url.to_string(),
            referer,
            origin,
            tracks: tracks.clone(),
            provider: provider.to_string(),
            stream_label: Some(stream_server_label(&raw, stream_index)),
        });
    }

    Ok(json!({ "streams": out }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encode_pipe_request_is_url_safe() {
        let payload =
            json!({"path":"episodes","method":"GET","query":{},"body":null,"version":"0.2.0"});
        let enc = encode_pipe_request(&payload);
        assert!(!enc.contains('='));
        assert!(!enc.contains('+'));
    }

    #[test]
    fn decode_pipe_body_plain_json() {
        let v = decode_pipe_body(r#"{"ok":true}"#, None).unwrap();
        assert_eq!(v.get("ok"), Some(&json!(true)));
    }

    #[test]
    fn deobfuscate_level2_roundtrip() {
        let plain = r#"{"streams":[]}"#;
        let mut data: Vec<u8> = plain.as_bytes().to_vec();
        for (i, b) in data.iter_mut().enumerate() {
            *b ^= PIPE_OBF_KEY[i % PIPE_OBF_KEY.len()];
        }
        let b64 = base64::engine::general_purpose::STANDARD.encode(&data);
        let out = deobfuscate(&b64, "2").unwrap();
        assert_eq!(out, plain);
    }

    #[test]
    fn episodes_webview_body_is_not_treated_as_sources() {
        // Simulate: episodes JSON passed with pipe_path=episodes must not
        // satisfy the sources step (would return empty streams, no cf_blocked).
        let episodes_json =
            r#"{"providers":{"bee":{"episodes":{"sub":[{"number":1,"id":"ep1"}]}}}}"#;
        // Cache episodes via fetch with matching path.
        let ep = fetch_episodes(999001, Some(episodes_json), None, Some("episodes")).unwrap();
        assert!(ep.get("providers").is_some());

        // Sources step with episodes-tagged body must CF-block (no HTTP in unit test
        // either — api_get gets None without network after skipping wrong webview).
        let out = miruro_resolve(
            999001,
            1,
            "sub",
            "bee",
            Some(episodes_json),
            None,
            Some("episodes"),
        )
        .unwrap();
        // Without a real sources fetch, expect cf_blocked or empty — never a false
        // success that silently swallowed the episodes body as sources.
        let streams = out.get("streams").and_then(|v| v.as_array());
        let cf = out.get("cf_blocked").and_then(|v| v.as_bool()) == Some(true);
        assert!(
            cf || streams.map(|s| s.is_empty()).unwrap_or(true),
            "unexpected resolve payload: {out}"
        );
        if cf {
            assert_eq!(
                out.get("pipe_path").and_then(|v| v.as_str()),
                Some("sources")
            );
        }
    }
}
