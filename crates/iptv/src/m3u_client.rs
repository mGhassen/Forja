//! M3U / M3U8 playlist catalog fetch — HTTP GET (or local `file://` read) +
//! parse → Xtream-shaped rows.
//!
//! Remote playlists stream to a temp file rather than buffering the whole
//! response in memory twice (once in reqwest, once in our own `String`) —
//! provider exports can run into the hundreds of megabytes.

use crate::m3u::{self, M3uChannel};
use crate::xtream::{merge_orphan_categories, ParsedCategory, XtreamStreamRow};
use futures_util::StreamExt;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::time::Duration;
use tokio::io::AsyncWriteExt;

const DEFAULT_UA: &str = "VLC/3.0.20 LibVLC/3.0.20";

/// Provider playlist exports can be very large and some hosts stream them
/// slowly — give the m3u fetch far more headroom than a normal Xtream /
/// Stalker catalog call.
const MAX_TIMEOUT_SECS: u64 = 600;

#[derive(Debug, Deserialize)]
struct M3uRequest {
    action: String,
    #[serde(default)]
    url: String,
    #[serde(default)]
    user_agent: String,
    #[serde(default)]
    timeout_secs: u64,
}

pub fn request_json(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        return handle.block_on(request_json_async(request_json));
    }
    match tokio::runtime::Runtime::new() {
        Ok(rt) => rt.block_on(request_json_async(request_json)),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

pub async fn request_json_async(request_json: &str) -> String {
    utils::engine_cancel::enter_job();
    match handle(request_json).await {
        Ok(v) => v.to_string(),
        Err(e) => json!({ "error": e }).to_string(),
    }
}

async fn handle(request_json: &str) -> Result<Value, String> {
    let req: M3uRequest =
        serde_json::from_str(request_json).map_err(|e| format!("invalid request: {e}"))?;
    let timeout = Duration::from_secs(if req.timeout_secs == 0 {
        30
    } else {
        req.timeout_secs.clamp(1, MAX_TIMEOUT_SECS)
    });
    match req.action.as_str() {
        "login" => login(&req.url, &req.user_agent, timeout).await,
        "catalog" | "categories" | "streams" => catalog(&req.url, &req.user_agent, timeout).await,
        other => Err(format!("unknown action: {other}")),
    }
}

struct FetchedPlaylist {
    channels: Vec<M3uChannel>,
    epg_url: Option<String>,
}

async fn login(url: &str, ua: &str, timeout: Duration) -> Result<Value, String> {
    let fetched = fetch_playlist(url, ua, timeout).await?;
    if fetched.channels.is_empty() {
        return Err("no_channels".into());
    }
    let mut root = json!({
        "user_info": {
            "username": "M3U",
            "auth": "1",
            "status": "Active",
            "exp_date": "",
            "max_connections": "1",
            "active_cons": "0",
            "channel_count": fetched.channels.len(),
        }
    });
    if let Some(epg) = &fetched.epg_url {
        root["epg_url"] = json!(epg);
    }
    Ok(root)
}

async fn catalog(url: &str, ua: &str, timeout: Duration) -> Result<Value, String> {
    let fetched = fetch_playlist(url, ua, timeout).await?;
    let (cats, streams) = channels_to_catalog(&fetched.channels);
    let mut root = json!({
        "categories": cats,
        "streams": streams,
    });
    if let Some(epg) = &fetched.epg_url {
        root["epg_url"] = json!(epg);
    }
    Ok(root)
}

async fn fetch_playlist(url: &str, ua: &str, timeout: Duration) -> Result<FetchedPlaylist, String> {
    let raw = url.trim();
    if raw.is_empty() {
        return Err("empty url".into());
    }
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message().into());
    }
    let normalized = normalize_playlist_url(raw);

    let text = if let Some(path) = file_url_path(&normalized) {
        read_local_file(&path)?
    } else {
        download_playlist(&normalized, ua, timeout).await?
    };

    let result = m3u::parse_with_header(&text).map_err(|e| e.to_string())?;
    Ok(FetchedPlaylist {
        channels: result.channels,
        epg_url: result.epg_url,
    })
}

/// Xtream `get.php` links yield a parseable playlist for `type=m3u` and
/// `type=m3u_plus`; any other value (`gigablue`, `dreambox`, `enigma2`, …)
/// returns a set-top-box bouquet that can't be parsed. Rewrite to
/// `m3u_plus` unconditionally — it's a strict superset of plain `m3u`
/// (adds `tvg-*` / `group-title` attributes) — so both freshly-added and
/// already-stored playlists self-heal on their next fetch. Only
/// already-`m3u_plus` URLs and non-`get.php` URLs pass through untouched.
fn normalize_playlist_url(url: &str) -> String {
    let Some(q_idx) = url.find('?') else {
        return url.to_string();
    };
    let (path_part, query_part) = url.split_at(q_idx);
    if !path_part.to_ascii_lowercase().ends_with("get.php") {
        return url.to_string();
    }
    let query = &query_part[1..];
    let mut found_type = false;
    let mut needs_rewrite = false;
    let mut pairs: Vec<String> = Vec::new();
    for pair in query.split('&') {
        if let Some((k, v)) = pair.split_once('=') {
            if k.eq_ignore_ascii_case("type") {
                found_type = true;
                if !v.eq_ignore_ascii_case("m3u_plus") {
                    needs_rewrite = true;
                    pairs.push(format!("{k}=m3u_plus"));
                    continue;
                }
            }
        }
        pairs.push(pair.to_string());
    }
    if !found_type || !needs_rewrite {
        return url.to_string();
    }
    format!("{path_part}?{}", pairs.join("&"))
}

/// Extracts a local filesystem path from a `file://` URL, when `url` is one.
/// Accepts both `file:///abs/path` and a bare `file://relative` form.
fn file_url_path(url: &str) -> Option<PathBuf> {
    let rest = url.strip_prefix("file://")?;
    let decoded = urlencoding::decode(rest)
        .map(|c| c.into_owned())
        .unwrap_or_else(|_| rest.to_string());
    Some(PathBuf::from(decoded))
}

fn read_local_file(path: &Path) -> Result<String, String> {
    if !path.exists() {
        return Err("file_not_found".into());
    }
    std::fs::read_to_string(path).map_err(|e| e.to_string())
}

fn temp_file_path(suffix: &str) -> PathBuf {
    let mut buf = [0u8; 8];
    let _ = getrandom::getrandom(&mut buf);
    let mut hex = String::with_capacity(buf.len() * 2);
    for b in buf {
        hex.push_str(&format!("{b:02x}"));
    }
    std::env::temp_dir().join(format!("forja-iptv-{hex}{suffix}"))
}

/// Downloads the playlist behind `url` to a temp file (streamed, not
/// buffered in memory), then reads it back as text for [`m3u::parse_with_header`].
/// The temp file is removed once read, on every exit path.
async fn download_playlist(url: &str, ua: &str, timeout: Duration) -> Result<String, String> {
    let agent = if ua.trim().is_empty() {
        DEFAULT_UA
    } else {
        ua.trim()
    };
    let client = reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .map_err(|e| e.to_string())?;
    let resp = client
        .get(url)
        .header("User-Agent", agent)
        .header("Accept", "*/*")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    if !(200..300).contains(&status) {
        return Err(format!("HTTP {status}"));
    }

    let tmp_path = temp_file_path(".m3u");
    let download_result = stream_to_file(resp, &tmp_path).await;
    if let Err(e) = download_result {
        let _ = tokio::fs::remove_file(&tmp_path).await;
        return Err(e);
    }

    let text = tokio::fs::read_to_string(&tmp_path).await.map_err(|e| e.to_string());
    let _ = tokio::fs::remove_file(&tmp_path).await;
    text
}

async fn stream_to_file(resp: reqwest::Response, dest: &Path) -> Result<(), String> {
    let mut file = tokio::fs::File::create(dest).await.map_err(|e| e.to_string())?;
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = stream.next().await {
        if utils::engine_cancel::is_requested() {
            return Err(utils::engine_cancel::cancelled_message().into());
        }
        let chunk = chunk.map_err(|e| e.to_string())?;
        file.write_all(&chunk).await.map_err(|e| e.to_string())?;
    }
    file.flush().await.map_err(|e| e.to_string())
}

fn channels_to_catalog(channels: &[M3uChannel]) -> (Vec<ParsedCategory>, Vec<XtreamStreamRow>) {
    let mut group_order: BTreeMap<String, String> = BTreeMap::new();
    let mut streams = Vec::with_capacity(channels.len());
    for (i, ch) in channels.iter().enumerate() {
        let group = if ch.group.trim().is_empty() {
            "Uncategorized".to_string()
        } else {
            ch.group.trim().to_string()
        };
        let cat_id = format!("g:{}", group.to_ascii_lowercase());
        group_order.entry(cat_id.clone()).or_insert(group);
        // Loose classification: most M3U providers are live-only and never
        // set `type=`; only distinguish VOD/series when the entry says so
        // explicitly, rather than guessing from the URL.
        let kind = match ch.entry_type.as_deref() {
            Some(t) if t.eq_ignore_ascii_case("video") || t.eq_ignore_ascii_case("movie") => "vod",
            Some(t) if t.eq_ignore_ascii_case("series") => "series",
            _ => "live",
        };
        streams.push(XtreamStreamRow {
            // Encode playable URL as stream_id for M3U (no path build on host).
            stream_id: ch.url.clone(),
            name: if ch.name.is_empty() {
                format!("Channel {}", i + 1)
            } else {
                ch.name.clone()
            },
            icon: ch.logo.clone(),
            category_id: cat_id,
            container_ext: if kind == "live" { "ts".into() } else { "mp4".into() },
            epg_channel_id: ch.tvg_id.clone(),
            kind: kind.into(),
        });
    }
    let cats: Vec<ParsedCategory> = group_order
        .into_iter()
        .map(|(id, name)| ParsedCategory { id, name })
        .collect();
    let cats = merge_orphan_categories(cats, &streams);
    (cats, streams)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ch(name: &str, url: &str, group: &str) -> M3uChannel {
        M3uChannel {
            name: name.into(),
            url: url.into(),
            logo: String::new(),
            group: group.into(),
            tvg_id: String::new(),
            tvg_name: String::new(),
            entry_type: None,
        }
    }

    #[test]
    fn catalog_from_channels() {
        let channels = vec![ch("A", "http://x/a", "News"), ch("B", "http://x/b", "News")];
        let (cats, streams) = channels_to_catalog(&channels);
        assert_eq!(cats.len(), 1);
        assert_eq!(streams.len(), 2);
        assert_eq!(streams[0].stream_id, "http://x/a");
        assert_eq!(streams[0].kind, "live");
    }

    #[test]
    fn classifies_video_type_as_vod() {
        let mut movie = ch("Movie", "http://x/m", "Movies");
        movie.entry_type = Some("video".into());
        let (_, streams) = channels_to_catalog(&[movie]);
        assert_eq!(streams[0].kind, "vod");
        assert_eq!(streams[0].container_ext, "mp4");
    }

    #[test]
    fn normalizes_get_php_type_to_m3u_plus() {
        let url = "http://host/get.php?username=u&password=p&type=m3u8";
        assert_eq!(
            normalize_playlist_url(url),
            "http://host/get.php?username=u&password=p&type=m3u_plus"
        );
    }

    #[test]
    fn leaves_m3u_plus_untouched() {
        let url = "http://host/get.php?username=u&password=p&type=m3u_plus";
        assert_eq!(normalize_playlist_url(url), url);
    }

    #[test]
    fn leaves_non_get_php_untouched() {
        let url = "http://host/playlist.m3u8?token=abc";
        assert_eq!(normalize_playlist_url(url), url);
    }

    #[test]
    fn extracts_file_url_path() {
        let path = file_url_path("file:///Users/me/playlist.m3u").unwrap();
        assert_eq!(path, PathBuf::from("/Users/me/playlist.m3u"));
    }

    #[test]
    fn non_file_url_has_no_path() {
        assert!(file_url_path("http://example.com/x.m3u").is_none());
    }
}
