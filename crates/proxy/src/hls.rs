use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, HeaderMap, Method, StatusCode},
    response::Response,
};
use flate2::read::{GzDecoder, ZlibDecoder};
use serde::Deserialize;
use std::collections::HashMap;
use std::io::Read;

use crate::{forward_response, parse_custom_headers, ProxyState};

#[derive(Debug, Deserialize)]
pub struct HlsProxyQuery {
    pub url: String,
    pub headers: Option<String>,
    pub strip: Option<String>,
}

pub fn strip_png_wrapper(raw: &[u8]) -> Vec<u8> {
    if raw.len() < 16 {
        return raw.to_vec();
    }
    // embedindia PPV: a 13-byte VP8L still, then an EXIF chunk that is raw
    // MPEG-TS. The web player reads that chunk. MediaKit sees WEBP and EOFs.
    if let Some(ts) = strip_riff_chunk_ts(raw) {
        return ts;
    }
    if raw[0] != 0x89 || raw[1] != 0x50 || raw[2] != 0x4E || raw[3] != 0x47 {
        return raw.to_vec();
    }
    // Daddy / Streamic: MPEG-TS gzipped into RGB pixels (magic TIKTIKPX),
    // not appended after IEND. Must run before the IEND scan — compressed
    // IDAT can contain the ASCII "IEND" and that scan would return junk.
    if let Some(ts) = png_pixel_ts(raw) {
        return ts;
    }
    let mut idx = None;
    for i in 8..raw.len().saturating_sub(8) {
        if raw[i] == 0x49 && raw[i + 1] == 0x45 && raw[i + 2] == 0x4E && raw[i + 3] == 0x44 {
            idx = Some(i + 8);
            break;
        }
    }
    if let Some(start) = idx {
        for p in start..raw.len().saturating_sub(188) {
            if raw[p] == 0x47 && raw[p + 188] == 0x47 {
                return raw[p..].to_vec();
            }
        }
        for p in start..raw.len() {
            if raw[p] == 0x47 {
                return raw[p..].to_vec();
            }
        }
        // KissKh / videotradercdn: PNG shell over fMP4 or other media — no TS
        // sync. Still drop the PNG so the demuxer sees the real payload.
        if start < raw.len() {
            return raw[start..].to_vec();
        }
    }
    // Megaplay / nekostream: fixed 252-byte PNG header before MPEG-TS.
    if raw.len() > 252 + 188 && raw[252] == 0x47 && raw[252 + 188] == 0x47 {
        return raw[252..].to_vec();
    }
    raw.to_vec()
}

/// RIFF/WEBP whose chunk payload is MPEG-TS (sync `0x47` every 188 bytes).
/// embedindia writes the TS into an `EXIF` chunk after a tiny `VP8L` still.
fn strip_riff_chunk_ts(raw: &[u8]) -> Option<Vec<u8>> {
    if raw.len() < 12 || &raw[..4] != b"RIFF" || &raw[8..12] != b"WEBP" {
        return None;
    }
    let mut off = 12usize;
    while off + 8 <= raw.len() {
        let size = u32::from_le_bytes(raw.get(off + 4..off + 8)?.try_into().ok()?) as usize;
        let start = off + 8;
        let end = start.checked_add(size)?;
        if end > raw.len() {
            return None;
        }
        let payload = raw.get(start..end)?;
        if payload.len() >= 188 && payload[0] == 0x47 && payload.get(188) == Some(&0x47) {
            return Some(payload.to_vec());
        }
        off = end + (size & 1);
    }
    None
}

/// `TIKTIKPX` — MPEG-TS gzip stored in reconstructed RGB (Streamic / daddy).
const TIKTIK_PX: &[u8] = b"TIKTIKPX";

fn paeth(a: u8, b: u8, c: u8) -> u8 {
    let a = a as i16;
    let b = b as i16;
    let c = c as i16;
    let p = a + b - c;
    let pa = (p - a).abs();
    let pb = (p - b).abs();
    let pc = (p - c).abs();
    if pa <= pb && pa <= pc {
        a as u8
    } else if pb <= pc {
        b as u8
    } else {
        c as u8
    }
}

/// Decode a PNG whose RGB pixels start with `TIKTIKPX`, a big-endian length,
/// and a gzip of MPEG-TS. Matches the daddy player `unwrapPixels` path.
fn png_pixel_ts(raw: &[u8]) -> Option<Vec<u8>> {
    if raw.len() < 8 || raw[0] != 0x89 || raw[1] != 0x50 {
        return None;
    }
    let mut off = 8usize;
    let mut w = 0u32;
    let mut h = 0u32;
    let mut depth = 0u8;
    let mut ctype = 0u8;
    let mut interlace = 0u8;
    let mut idat = Vec::new();
    while off + 8 <= raw.len() {
        let len = u32::from_be_bytes(raw.get(off..off + 4)?.try_into().ok()?) as usize;
        if off + 12 + len > raw.len() {
            return None;
        }
        let typ = raw.get(off + 4..off + 8)?;
        let data = raw.get(off + 8..off + 8 + len)?;
        if typ == b"IHDR" {
            if data.len() < 13 {
                return None;
            }
            w = u32::from_be_bytes(data[0..4].try_into().ok()?);
            h = u32::from_be_bytes(data[4..8].try_into().ok()?);
            depth = data[8];
            ctype = data[9];
            interlace = data[12];
        } else if typ == b"IDAT" {
            idat.extend_from_slice(data);
        } else if typ == b"IEND" {
            break;
        }
        off += 12 + len;
    }
    if w == 0 || h == 0 || depth != 8 || interlace != 0 || (ctype != 2 && ctype != 6) {
        return None;
    }
    let bpp: usize = if ctype == 6 { 4 } else { 3 };
    let stride = (w as usize).checked_mul(bpp)?;
    let rgb_len = (w as usize).checked_mul(h as usize)?.checked_mul(3)?;
    // Live segments are a few MB. Reject anything that would balloon.
    if stride == 0 || rgb_len == 0 || rgb_len > 32 * 1024 * 1024 {
        return None;
    }
    let mut inflated = Vec::new();
    ZlibDecoder::new(&idat[..])
        .read_to_end(&mut inflated)
        .ok()?;
    let mut rgb = vec![0u8; rgb_len];
    let mut src = 0usize;
    let mut dst = 0usize;
    let mut prev = vec![0u8; stride];
    for _y in 0..h as usize {
        if src + 1 + stride > inflated.len() {
            return None;
        }
        let filter = inflated[src];
        src += 1;
        let row = &inflated[src..src + stride];
        src += stride;
        let mut recon = vec![0u8; stride];
        for i in 0..stride {
            let left = if i >= bpp { recon[i - bpp] } else { 0 };
            let up = prev[i];
            let up_left = if i >= bpp { prev[i - bpp] } else { 0 };
            let mut v = row[i] as u16;
            match filter {
                0 => {}
                1 => v += left as u16,
                2 => v += up as u16,
                3 => v += (left as u16 + up as u16) >> 1,
                4 => v += paeth(left, up, up_left) as u16,
                _ => return None,
            }
            recon[i] = (v & 255) as u8;
        }
        if ctype == 2 {
            rgb[dst..dst + stride].copy_from_slice(&recon);
            dst += stride;
        } else {
            let mut i = 0;
            while i + 3 < stride {
                rgb[dst] = recon[i];
                rgb[dst + 1] = recon[i + 1];
                rgb[dst + 2] = recon[i + 2];
                dst += 3;
                i += 4;
            }
        }
        prev = recon;
    }
    if rgb.len() < 12 || &rgb[..8] != TIKTIK_PX {
        return None;
    }
    let n = u32::from_be_bytes(rgb.get(8..12)?.try_into().ok()?) as usize;
    if n == 0 || 12 + n > rgb.len() {
        return None;
    }
    let gz = rgb.get(12..12 + n)?;
    if gz.len() < 2 || gz[0] != 0x1f || gz[1] != 0x8b {
        return None;
    }
    let mut ts = Vec::new();
    GzDecoder::new(gz).read_to_end(&mut ts).ok()?;
    if ts.first() != Some(&0x47) {
        return None;
    }
    Some(ts)
}

/// True when bytes are a PNG that wraps MPEG-TS (Megaplay anti-scraper).
#[allow(dead_code)] // used by unit tests; strip path inlines the same logic
pub fn png_wraps_mpeg_ts(raw: &[u8]) -> bool {
    if raw.len() < 16 {
        return false;
    }
    if raw[0] != 0x89 || raw[1] != 0x50 || raw[2] != 0x4E || raw[3] != 0x47 {
        return false;
    }
    let stripped = strip_png_wrapper(raw);
    stripped.len() < raw.len() && !stripped.is_empty() && stripped[0] == 0x47
}

fn resolve_url(relative: &str, base_path: &str, server_base: &str) -> String {
    let trimmed = relative.trim();
    let resolved = if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        trimmed.to_string()
    } else if let Some(rest) = trimmed.strip_prefix("//") {
        // Protocol-relative (`//cdn.example/seg`) — must NOT be treated as a
        // path under server_base (that produced `https://hostA//hostB/…`).
        let scheme = if base_path.starts_with("https://") || server_base.starts_with("https://") {
            "https"
        } else {
            "http"
        };
        format!("{scheme}://{rest}")
    } else if trimmed.starts_with('/') {
        format!("{server_base}{trimmed}")
    } else {
        format!("{base_path}{trimmed}")
    };
    collapse_double_authority(&resolved)
}

/// Repair `https://hostA//hostB/path` (and `https://hostA//https://hostB/…`)
/// from bad protocol-relative joins or CDN quirks.
fn collapse_double_authority(url: &str) -> String {
    let Some(scheme_end) = url.find("://") else {
        return url.to_string();
    };
    let after_scheme = &url[scheme_end + 3..];
    let Some(dbl) = after_scheme.find("//") else {
        return url.to_string();
    };
    let second = after_scheme[dbl + 2..].trim_start_matches('/');
    if second.is_empty() {
        return url.to_string();
    }
    if second.starts_with("http://") || second.starts_with("https://") {
        return second.to_string();
    }
    // Second authority looks like a host (has a dot before first slash).
    let host_part = second.split('/').next().unwrap_or("");
    if !host_part.contains('.') {
        return url.to_string();
    }
    let scheme = &url[..scheme_end];
    format!("{scheme}://{second}")
}

pub fn build_hls_proxy_url(
    proxy_base: &str,
    target: &str,
    headers_json: &str,
    strip: Option<&str>,
) -> String {
    let mut out = format!(
        "{proxy_base}?url={}&headers={}",
        urlencoding::encode(target),
        urlencoding::encode(headers_json)
    );
    if let Some(mode) = strip.filter(|s| !s.is_empty()) {
        out.push_str("&strip=");
        out.push_str(&urlencoding::encode(mode));
    }
    out
}

/// Rewrite playlist URIs to paths relative to [session_base] so `/ext/{id}/…`
/// relative resolution keeps cookies on nested playlists and segments.
pub fn rewrite_hls_playlist_relative(body: &str, decoded_url: &str, session_base: &str) -> String {
    let slash = decoded_url.rfind('/').unwrap_or(0);
    let base_path = &decoded_url[..=slash];
    let server_base = if let Some(scheme_end) = decoded_url.find("://") {
        let rest = &decoded_url[scheme_end + 3..];
        if let Some(path_start) = rest.find('/') {
            &decoded_url[..scheme_end + 3 + path_start]
        } else {
            decoded_url
        }
    } else {
        decoded_url
    };

    let to_rel = |full: &str| -> String {
        if let Some(rest) = full.strip_prefix(session_base) {
            return rest.to_string();
        }
        full.to_string()
    };

    let mut forja_subs = Vec::new();
    let playlist = body
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if is_hls_subtitle_media(trimmed) {
                if let Some(uri) = hls_quoted_attr(trimmed, "URI") {
                    let full = resolve_url(&uri, base_path, server_base);
                    let play = to_rel(&full);
                    if let Some(sub) = forja_sub_fields(trimmed, play) {
                        forja_subs.push(sub);
                    }
                }
                return None;
            }
            let line = strip_stream_inf_subtitles_attr(line);
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                if trimmed.contains("URI=\"") {
                    let mut out = line.to_string();
                    let mut search_from = 0;
                    while let Some(rel) = out[search_from..].find("URI=\"") {
                        let start = search_from + rel;
                        let rest = &out[start + 5..];
                        let Some(end) = rest.find('"') else { break };
                        let uri = &rest[..end];
                        let full = resolve_url(uri, base_path, server_base);
                        let replacement = to_rel(&full);
                        let new_token = format!("URI=\"{replacement}\"");
                        out.replace_range(start..start + 5 + end + 1, &new_token);
                        search_from = start + new_token.len();
                    }
                    return Some(out);
                }
                return Some(line.to_string());
            }
            let full = resolve_url(trimmed, base_path, server_base);
            Some(to_rel(&full))
        })
        .collect::<Vec<_>>()
        .join("\n");
    append_forja_sub_comments(playlist, &forja_subs)
}

pub fn rewrite_hls_playlist(
    body: &str,
    decoded_url: &str,
    proxy_base: &str,
    headers_json: &str,
    strip: Option<&str>,
) -> String {
    let slash = decoded_url.rfind('/').unwrap_or(0);
    let base_path = &decoded_url[..=slash];
    let server_base = if let Some(scheme_end) = decoded_url.find("://") {
        let rest = &decoded_url[scheme_end + 3..];
        if let Some(path_start) = rest.find('/') {
            &decoded_url[..scheme_end + 3 + path_start]
        } else {
            decoded_url
        }
    } else {
        decoded_url
    };

    let mut forja_subs = Vec::new();
    let playlist = body
        .lines()
        .filter_map(|line| {
            let trimmed = line.trim();
            if is_hls_subtitle_media(trimmed) {
                if let Some(uri) = hls_quoted_attr(trimmed, "URI") {
                    let full = resolve_url(&uri, base_path, server_base);
                    let play = build_hls_proxy_url(proxy_base, &full, headers_json, strip);
                    if let Some(sub) = forja_sub_fields(trimmed, play) {
                        forja_subs.push(sub);
                    }
                }
                return None;
            }
            let line = strip_stream_inf_subtitles_attr(line);
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                if trimmed.contains("URI=\"") {
                    let mut out = line.to_string();
                    let mut search_from = 0;
                    while let Some(rel) = out[search_from..].find("URI=\"") {
                        let start = search_from + rel;
                        let rest = &out[start + 5..];
                        let Some(end) = rest.find('"') else { break };
                        let uri = &rest[..end];
                        let full = resolve_url(uri, base_path, server_base);
                        let replacement =
                            build_hls_proxy_url(proxy_base, &full, headers_json, strip);
                        let new_token = format!("URI=\"{replacement}\"");
                        out.replace_range(start..start + 5 + end + 1, &new_token);
                        search_from = start + new_token.len();
                    }
                    return Some(out);
                }
                return Some(line.to_string());
            }
            let full = resolve_url(trimmed, base_path, server_base);
            Some(build_hls_proxy_url(proxy_base, &full, headers_json, strip))
        })
        .collect::<Vec<_>>()
        .join("\n");
    append_forja_sub_comments(playlist, &forja_subs)
}

fn is_plain_image_uri(uri: &str) -> bool {
    let path = uri.split('?').next().unwrap_or(uri).to_ascii_lowercase();
    path.ends_with(".png")
        || path.ends_with(".jpg")
        || path.ends_with(".jpeg")
        || path.ends_with(".gif")
        || path.ends_with(".webp")
        || path.ends_with(".svg")
        // embedindia WAF decoy segments (TikTok CDN stills as "HLS").
        || path.ends_with(".image")
        || (path.contains("tiktokcdn") && path.contains("tplv-tiktokx-origin"))
}

/// True when every media URI is a still image (WAF decoy), not HLS/TS/fMP4.
pub fn hls_playlist_is_image_bait(body: &str) -> bool {
    let mut uris = 0usize;
    for line in body.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        uris += 1;
        if !is_plain_image_uri(trimmed) {
            return false;
        }
    }
    uris > 0
}

fn is_hls_subtitle_media(line: &str) -> bool {
    let t = line.trim();
    if !t.starts_with("#EXT-X-MEDIA:") {
        return false;
    }
    t.to_ascii_uppercase().contains("TYPE=SUBTITLES")
}

/// `KEY="value"` on an HLS tag. Matching is case-insensitive; the value keeps
/// the original spelling.
fn hls_quoted_attr(line: &str, key: &str) -> Option<String> {
    let lower = line.to_ascii_lowercase();
    let needle = format!("{}=\"", key.to_ascii_lowercase());
    let i = lower.find(&needle)?;
    let start = i + needle.len();
    let rest = &line[start..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

/// lang, display name, play URI. LANGUAGE falls back to NAME.
fn forja_sub_fields(line: &str, play_uri: String) -> Option<(String, String, String)> {
    let play_uri = play_uri.trim().to_string();
    if play_uri.is_empty() {
        return None;
    }
    let name = hls_quoted_attr(line, "NAME")
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "Subtitles".to_string());
    let lang = hls_quoted_attr(line, "LANGUAGE")
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| name.clone());
    Some((lang, name, play_uri))
}

/// Playlist comment the subtitle menu reads. Not an HLS tag, so lavf does not
/// open every rendition at start.
fn append_forja_sub_comments(mut body: String, subs: &[(String, String, String)]) -> String {
    if subs.is_empty() {
        return body;
    }
    if !body.ends_with('\n') {
        body.push('\n');
    }
    for (lang, name, uri) in subs {
        body.push_str("#FORJA-SUB:lang=");
        body.push_str(&urlencoding::encode(lang));
        body.push_str("&name=");
        body.push_str(&urlencoding::encode(name));
        body.push_str("&uri=");
        body.push_str(&urlencoding::encode(uri));
        body.push('\n');
    }
    body
}

/// lavf waits on HLS `SUBTITLES=` groups (VixSrc ships ~30). Groups stay off the
/// variant the player demuxes. Renditions are re-emitted as `#FORJA-SUB:` so
/// the subtitle menu can load one of them.
fn strip_stream_inf_subtitles_attr(line: &str) -> String {
    let trimmed = line.trim();
    if !trimmed.to_ascii_uppercase().contains("#EXT-X-STREAM-INF:") {
        return line.to_string();
    }
    strip_quoted_attr(line, "SUBTITLES")
}

fn strip_quoted_attr(line: &str, attr: &str) -> String {
    let needle = format!("{attr}=\"");
    let lower = line.to_ascii_lowercase();
    let needle_l = needle.to_ascii_lowercase();
    let Some(i) = lower.find(&needle_l) else {
        return line.to_string();
    };
    let after = i + needle.len();
    let rest = &line[after..];
    let Some(end) = rest.find('"') else {
        return line.to_string();
    };
    let mut start = i;
    if start > 0 && line.as_bytes()[start - 1] == b',' {
        start -= 1;
    }
    format!("{}{}", &line[..start], &rest[end + 1..])
}

fn header_ci<'a>(custom_headers: &'a HashMap<String, String>, name: &str) -> Option<&'a str> {
    let want = name.to_ascii_lowercase();
    custom_headers
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(&want))
        .map(|(_, v)| v.as_str())
}

/// Playlist host. rustls and Chrome impersonation are nginx-403'd.
fn host_needs_chrome_tls(target_url: &str) -> bool {
    reqwest::Url::parse(target_url)
        .ok()
        .and_then(|u| {
            u.host_str()
                .map(|h| h.to_ascii_lowercase().contains("indianservers.st"))
        })
        .unwrap_or(false)
}

/// rustls, Dart, and Chrome-impersonation are nginx-403'd. CPython's LibreSSL is not.
fn libressl_fetch_bytes(
    target_url: &str,
    custom_headers: &HashMap<String, String>,
) -> Result<(StatusCode, String, Vec<u8>), StatusCode> {
    let script = r#"
import json, sys, urllib.request, urllib.error
req = json.load(sys.stdin)
r = urllib.request.Request(req["url"], headers=req.get("headers") or {})
try:
    with urllib.request.urlopen(r, timeout=20) as resp:
        body = resp.read()
        ctype = resp.headers.get("Content-Type") or ""
        sys.stdout.buffer.write(str(resp.status).encode() + b"\n")
        sys.stdout.buffer.write(ctype.encode() + b"\n")
        sys.stdout.buffer.write(body)
except urllib.error.HTTPError as e:
    body = e.read()
    ctype = e.headers.get("Content-Type") or ""
    sys.stdout.buffer.write(str(e.code).encode() + b"\n")
    sys.stdout.buffer.write(ctype.encode() + b"\n")
    sys.stdout.buffer.write(body)
"#;
    let payload = serde_json::json!({
        "url": target_url,
        "headers": custom_headers,
    });
    let mut child = std::process::Command::new("python3")
        .arg("-c")
        .arg(script)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|_| StatusCode::BAD_GATEWAY)?;
    {
        let stdin = child.stdin.as_mut().ok_or(StatusCode::BAD_GATEWAY)?;
        use std::io::Write;
        stdin
            .write_all(payload.to_string().as_bytes())
            .map_err(|_| StatusCode::BAD_GATEWAY)?;
    }
    let out = child
        .wait_with_output()
        .map_err(|_| StatusCode::BAD_GATEWAY)?;
    if !out.status.success() && out.stdout.is_empty() {
        return Err(StatusCode::BAD_GATEWAY);
    }
    let mut lines = out.stdout.splitn(3, |b| *b == b'\n');
    let status_raw = lines.next().unwrap_or_default();
    let ctype_raw = lines.next().unwrap_or_default();
    let body = lines.next().unwrap_or_default().to_vec();
    let status_num: u16 = String::from_utf8_lossy(status_raw)
        .trim()
        .parse()
        .unwrap_or(0);
    let status = StatusCode::from_u16(status_num).unwrap_or(StatusCode::BAD_GATEWAY);
    let content_type = String::from_utf8_lossy(ctype_raw).trim().to_lowercase();
    Ok((status, content_type, body))
}

pub(crate) fn build_hls_upstream_request(
    state: &ProxyState,
    method: Method,
    target_url: &str,
    custom_headers: &HashMap<String, String>,
    incoming: &HeaderMap,
) -> Result<reqwest::RequestBuilder, StatusCode> {
    let mut req = state.client.request(method, target_url);
    let ua = header_ci(custom_headers, "User-Agent")
        .map(str::to_owned)
        .unwrap_or_else(|| {
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36".into()
        });
    req = req.header(header::USER_AGENT, ua);
    if let Some(referer) = header_ci(custom_headers, "Referer") {
        req = req.header(header::REFERER, referer);
    }
    if let Some(origin) = header_ci(custom_headers, "Origin") {
        req = req.header(header::ORIGIN, origin);
    }
    // Live Matches / PPV CDN tokens live in WebView cookies — must forward.
    if let Some(cookie) = header_ci(custom_headers, "Cookie") {
        req = req.header(header::COOKIE, cookie);
    }
    if let Some(auth) = header_ci(custom_headers, "Authorization") {
        req = req.header(header::AUTHORIZATION, auth);
    }
    req = req.header(header::ACCEPT, "*/*");
    req = req.header(header::ACCEPT_ENCODING, "identity");
    req = req.header(header::CONNECTION, "keep-alive");
    if let Some(range) = incoming.get(header::RANGE) {
        req = req.header(header::RANGE, range);
    }
    Ok(req)
}

async fn finish_hls_proxy_body(
    state: &ProxyState,
    status: StatusCode,
    content_type: &str,
    bytes: Vec<u8>,
    target_url: &str,
    headers_json: &str,
    strip: Option<&str>,
) -> Result<Response, StatusCode> {
    let looks_like_playlist_url = content_type.contains("mpegurl")
        || content_type.contains("x-mpegurl")
        || target_url.contains(".m3u8")
        || target_url.contains("/playlist/");
    if looks_like_playlist_url {
        let body = String::from_utf8_lossy(&bytes).into_owned();
        let trimmed = body.trim_start();
        if !status.is_success() || !trimmed.starts_with("#EXTM3U") {
            let out_status = if status.is_success() {
                StatusCode::BAD_GATEWAY
            } else {
                status
            };
            return Response::builder()
                .status(out_status)
                .header(header::CONTENT_TYPE, "text/plain; charset=utf-8")
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .body(Body::from(body))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
        let effective_strip = if strip == Some("png") || hls_playlist_is_image_bait(&body) {
            Some("png")
        } else {
            strip
        };
        let port = *state.listen_port.read().await;
        let proxy_base = format!("http://127.0.0.1:{port}/hls-proxy");
        let rewritten = rewrite_hls_playlist(
            &body,
            target_url,
            &proxy_base,
            headers_json,
            effective_strip,
        );
        return Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/vnd.apple.mpegurl")
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .body(Body::from(rewritten))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }
    if strip == Some("png") {
        let stripped = strip_png_wrapper(&bytes);
        let content_type = if stripped.first() == Some(&0x47) {
            "video/mp2t"
        } else {
            "application/octet-stream"
        };
        let out_status = if status.is_success() {
            StatusCode::OK
        } else {
            status
        };
        return Response::builder()
            .status(out_status)
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .header(header::ACCEPT_RANGES, "bytes")
            .header(header::CONNECTION, "keep-alive")
            .header(header::CONTENT_TYPE, content_type)
            .header(header::CONTENT_LENGTH, stripped.len())
            .body(Body::from(stripped))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }
    Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, content_type)
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .body(Body::from(bytes))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn hls_proxy_handler(
    State(state): State<ProxyState>,
    Query(query): Query<HlsProxyQuery>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let raw_target = urlencoding::decode(&query.url)
        .map(|s| s.into_owned())
        .unwrap_or(query.url);
    // Defense: repair stale rewritten `hostA//hostB` targets before fetch.
    let target_url = collapse_double_authority(&raw_target);
    let custom = parse_custom_headers(query.headers.as_deref());
    let headers_json = query.headers.as_deref().unwrap_or("{}");
    let strip = query.strip.as_deref();

    // DASH via query-proxy cannot resolve relative SegmentTemplate (query is
    // dropped). Redirect into a path session so IINA/VLC/etc. keep cookies.
    if target_url.to_ascii_lowercase().contains(".mpd") {
        if let Some(play) = crate::ext::create_ext_session(&state, &target_url, headers_json).await
        {
            return Response::builder()
                .status(StatusCode::FOUND)
                .header(header::LOCATION, play)
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .body(Body::empty())
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
    }

    // Picture-shelled segments (strip=png) must be fetched whole. A Range
    // probe returns a partial PNG that cannot be inflated.
    let mut fetch_headers = headers.clone();
    if strip == Some("png") {
        fetch_headers.remove(header::RANGE);
    }
    if host_needs_chrome_tls(&target_url) {
        let url = target_url.clone();
        let headers = custom.clone();
        let (status, content_type, bytes) =
            tokio::task::spawn_blocking(move || libressl_fetch_bytes(&url, &headers))
                .await
                .map_err(|_| StatusCode::BAD_GATEWAY)??;
        return finish_hls_proxy_body(
            &state,
            status,
            &content_type,
            bytes,
            &target_url,
            headers_json,
            strip,
        )
        .await;
    }
    let req =
        build_hls_upstream_request(&state, method.clone(), &target_url, &custom, &fetch_headers)?;
    let resp = req.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    let status = resp.status();
    let content_type = resp
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_lowercase();

    let looks_like_playlist_url = content_type.contains("mpegurl")
        || content_type.contains("x-mpegurl")
        || target_url.contains(".m3u8")
        || target_url.contains("/playlist/");

    if looks_like_playlist_url {
        let body = resp.text().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        let trimmed = body.trim_start();
        // Never mask HTML/403 bodies as a 200 m3u8 — MediaKit then loops on
        // "Failed to recognize file format" and the IPTV watchdog reconnects forever.
        if !status.is_success() || !trimmed.starts_with("#EXTM3U") {
            let out_status = if status.is_success() {
                StatusCode::BAD_GATEWAY
            } else {
                StatusCode::from_u16(status.as_u16()).unwrap_or(StatusCode::BAD_GATEWAY)
            };
            return Response::builder()
                .status(out_status)
                .header(header::CONTENT_TYPE, "text/plain; charset=utf-8")
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .body(Body::from(body))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
        // URI ends in .png/.jpg/… — often a WAF stills decoy, but WatchFooty
        // `wfty.st` (and peers) serve real MPEG-TS under image filenames.
        // Don't 502 the playlist; rewrite children with strip=png so the
        // segment path sniffs TS / strips a PNG shell (KissKh path).
        let effective_strip = if strip == Some("png") || hls_playlist_is_image_bait(&body) {
            Some("png")
        } else {
            strip
        };
        let port = *state.listen_port.read().await;
        let proxy_base = format!("http://127.0.0.1:{port}/hls-proxy");
        let rewritten = rewrite_hls_playlist(
            &body,
            &target_url,
            &proxy_base,
            headers_json,
            effective_strip,
        );
        return Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/vnd.apple.mpegurl")
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .body(Body::from(rewritten))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    if strip == Some("png") {
        let bytes = resp.bytes().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        let stripped = strip_png_wrapper(&bytes);
        // MPEG-TS sync → mp2t; otherwise let the demuxer sniff (fMP4 / AV1).
        let content_type = if stripped.first() == Some(&0x47) {
            "video/mp2t"
        } else {
            "application/octet-stream"
        };
        // Unwrapped bodies are the full segment, not the client's Range.
        let out_status = if status.is_success() {
            StatusCode::OK
        } else {
            status
        };
        return Response::builder()
            .status(out_status)
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .header(header::ACCEPT_RANGES, "bytes")
            .header(header::CONNECTION, "keep-alive")
            .header(header::CONTENT_TYPE, content_type)
            .header(header::CONTENT_LENGTH, stripped.len())
            .body(Body::from(stripped))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    forward_response(resp)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_ci_is_case_insensitive() {
        let mut map = HashMap::new();
        map.insert("cookie".into(), "a=1".into());
        assert_eq!(header_ci(&map, "Cookie"), Some("a=1"));
        assert_eq!(header_ci(&map, "COOKIE"), Some("a=1"));
    }

    #[test]
    fn relative_hls_rewrite_keeps_nested_paths() {
        const MASTER: &str = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n720p/index.m3u8\n";
        let out = rewrite_hls_playlist_relative(
            MASTER,
            "https://cdn.example/path/master.m3u8",
            "https://cdn.example/path/",
        );
        assert!(out.contains("720p/index.m3u8"), "{out}");
        assert!(!out.contains("http://"), "{out}");
    }

    #[test]
    fn rewrites_segment_lines() {
        const MASTER: &str = "#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\n720p/index.m3u8\n";
        let out = rewrite_hls_playlist(
            MASTER,
            "https://cdn.example/path/master.m3u8",
            "http://127.0.0.1:9999/hls-proxy",
            r#"{"Referer":"https://ref/"}"#,
            None,
        );
        assert!(out.contains("http://127.0.0.1:9999/hls-proxy?url="));
        assert!(out.contains("720p%2Findex.m3u8") || out.contains("720p/index.m3u8"));
    }

    #[test]
    fn rewrites_root_relative_aes_key() {
        const BODY: &str = "\
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI=\"/storage/enc.key\",IV=0x01
https://cdn.example/seg.ts
";
        let out = rewrite_hls_playlist(
            BODY,
            "https://vixsrc.to/playlist/693466?type=video&rendition=1080p",
            "http://127.0.0.1:9/hls-proxy",
            "{}",
            None,
        );
        assert!(
            out.contains("url=https%3A%2F%2Fvixsrc.to%2Fstorage%2Fenc.key")
                || out.contains("url=https://vixsrc.to/storage/enc.key"),
            "KEY must resolve against playlist host, got:\n{out}"
        );
        assert!(!out.contains("cdn.example%2Fstorage"));
    }

    #[test]
    fn drops_hls_subtitle_groups() {
        const BODY: &str = "\
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Korean\",URI=\"/playlist/1?type=audio\"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",NAME=\"English\",LANGUAGE=\"en\",URI=\"/playlist/1?type=subtitle\"
#EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO=\"audio\",SUBTITLES=\"subs\"
/playlist/1?type=video
";
        let out = rewrite_hls_playlist(
            BODY,
            "https://vixsrc.to/playlist/1",
            "http://127.0.0.1:9/hls-proxy",
            "{}",
            None,
        );
        assert!(
            !out.to_ascii_uppercase().contains("TYPE=SUBTITLES"),
            "{out}"
        );
        assert!(!out.to_ascii_uppercase().contains("SUBTITLES="), "{out}");
        assert!(out.to_ascii_uppercase().contains("TYPE=AUDIO"), "{out}");
        assert!(out.contains("/hls-proxy?url="), "{out}");
        assert!(out.contains("#FORJA-SUB:"), "{out}");
        assert!(out.contains("lang=en"), "{out}");
        assert!(out.contains("name=English"), "{out}");
        assert!(
            out.contains("type%253Dsubtitle") || out.contains("subtitle"),
            "{out}"
        );
    }

    #[test]
    fn rewrites_uri_attributes() {
        const BODY: &str = "#EXT-X-MAP:URI=\"init.mp4\"\nseg.ts\n";
        let out = rewrite_hls_playlist(
            BODY,
            "https://cdn.example/vid/playlist.m3u8",
            "http://127.0.0.1:1/hls-proxy",
            "{}",
            Some("png"),
        );
        assert!(out.contains("URI=\"http://127.0.0.1:1/hls-proxy"));
        assert!(out.contains("strip=png"));
    }

    #[test]
    fn strip_png_finds_ts_after_iend() {
        let mut raw = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        raw.extend(std::iter::repeat_n(0u8, 8));
        raw.extend_from_slice(b"IEND");
        raw.extend([0, 0, 0, 0]); // CRC placeholder
        raw.push(0x47);
        raw.extend(std::iter::repeat_n(0u8, 187));
        raw.push(0x47);
        let out = strip_png_wrapper(&raw);
        assert_eq!(out[0], 0x47);
        assert!(png_wraps_mpeg_ts(&raw));
    }

    #[test]
    fn strip_png_megaplay_offset_252() {
        let mut raw = vec![0x89, 0x50, 0x4E, 0x47];
        raw.extend(std::iter::repeat_n(0u8, 248));
        raw.push(0x47);
        raw.extend(std::iter::repeat_n(0u8, 187));
        raw.push(0x47);
        assert_eq!(raw.len(), 252 + 189);
        let out = strip_png_wrapper(&raw);
        assert_eq!(out[0], 0x47);
        assert!(png_wraps_mpeg_ts(&raw));
    }

    #[test]
    fn resolve_protocol_relative_keeps_host() {
        let out = resolve_url(
            "//hls20.cdnvideo11.shop/child/2160/x.m3u8",
            "https://hls19.cdnvideo11.shop/master/",
            "https://hls19.cdnvideo11.shop",
        );
        assert_eq!(out, "https://hls20.cdnvideo11.shop/child/2160/x.m3u8");
    }

    #[test]
    fn collapse_double_authority_repairs_bad_join() {
        let out = collapse_double_authority(
            "https://hls20.cdnvideo11.shop//hls19.videotradercdn.site/segment/x.png",
        );
        assert_eq!(out, "https://hls19.videotradercdn.site/segment/x.png");
    }

    #[test]
    fn rewrite_kisskh_protocol_relative_segments() {
        const MEDIA: &str = "\
#EXTM3U
#EXT-X-MAP:URI=\"//hls19.videotradercdn.site/segment/k/1080/init.png\"
#EXTINF:3.0,
//hls19.videotradercdn.site/segment/k/1080/seg.png
";
        let out = rewrite_hls_playlist(
            MEDIA,
            "https://hls20.cdnvideo11.shop/child/k/1080/index.m3u8",
            "http://127.0.0.1:9/hls-proxy",
            "{}",
            Some("png"),
        );
        assert!(
            out.contains("url=https%3A%2F%2Fhls19.videotradercdn.site%2Fsegment"),
            "expected protocol-relative → https://hls19…, got:\n{out}"
        );
        assert!(
            !out.contains("cdnvideo11.shop%2F%2Fhls19"),
            "must not emit hostA//hostB joins:\n{out}"
        );
    }

    #[test]
    fn image_bait_playlist_rewrites_with_strip_png() {
        const BODY: &str = "\
#EXTM3U
#EXTINF:4,
https://cdn.example/anon/seg.png
";
        assert!(hls_playlist_is_image_bait(BODY));
        let out = rewrite_hls_playlist(
            BODY,
            "https://lb1.wfty.st/secure/tok/pro/slug/1/1/1/playlist.m3u8",
            "http://127.0.0.1:9/hls-proxy",
            r#"{"Referer":"https://sportsembed.su/embed/1/slug/pro/1"}"#,
            Some("png"),
        );
        assert!(out.contains("strip=png"), "{out}");
        assert!(out.contains("seg.png"), "{out}");
    }

    #[test]
    fn image_bait_playlist_is_detected() {
        const BAIT: &str = "\
#EXTM3U
#EXT-X-VERSION:3
#EXTINF:10,
https://media.bitstudio.ai/user-content/x.png
#EXTINF:10,
https://cdn.example/lumeflow/y.png
";
        assert!(hls_playlist_is_image_bait(BAIT));
        assert!(!hls_playlist_is_image_bait(
            "#EXTM3U\n#EXTINF:4,\nhttps://lb6.wfty.st/secure/tok/seg.ts\n"
        ));
        // .png media URIs classify as image-bait; handler upgrades to strip=png
        // so MPEG-TS / PNG-wrapped TS (WatchFooty, KissKh) still proxies.
        assert!(hls_playlist_is_image_bait(
            "#EXTM3U\n#EXTINF:3,\n//cdn.example/seg.png\n"
        ));
        assert!(hls_playlist_is_image_bait(
            "#EXTM3U\n#EXTINF:4,\nhttps://p16-common-sign.tiktokcdn-eu.com/tos-x~tplv-tiktokx-origin.image?x=1\n"
        ));
        // WatchFooty-style: image filenames that are still playable via strip.
        assert!(hls_playlist_is_image_bait(
            "#EXTM3U\n#EXTINF:4,\nhttps://cdn.example/anon/seg.png\n"
        ));
    }

    #[test]
    fn strip_png_unwraps_webp_exif_mpeg_ts() {
        let mut ts = vec![0x47u8, 0x40, 0x00, 0x10];
        ts.resize(188, 0);
        ts.push(0x47);
        ts.resize(376, 0x11);
        let chunk = |typ: &[u8], data: &[u8]| {
            let mut c = Vec::new();
            c.extend_from_slice(typ);
            c.extend_from_slice(&(data.len() as u32).to_le_bytes());
            c.extend_from_slice(data);
            if data.len() % 2 == 1 {
                c.push(0);
            }
            c
        };
        let vp8l = chunk(
            b"VP8L",
            &[
                0x2f, 0, 0, 0, 0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xfe, 0x07,
            ],
        );
        let exif = chunk(b"EXIF", &ts);
        let mut raw = Vec::new();
        raw.extend_from_slice(b"RIFF");
        let payload_len = (4 + vp8l.len() + exif.len()) as u32;
        raw.extend_from_slice(&payload_len.to_le_bytes());
        raw.extend_from_slice(b"WEBP");
        raw.extend_from_slice(&vp8l);
        raw.extend_from_slice(&exif);
        let out = strip_png_wrapper(&raw);
        assert_eq!(out, ts);
        assert_eq!(out.first(), Some(&0x47));
    }

    #[test]
    fn strip_png_unwraps_tiktok_pixel_gzip() {
        let ts = {
            let mut v = vec![0x47u8];
            v.extend(std::iter::repeat_n(0u8, 187));
            v.push(0x47);
            v
        };
        let gz = {
            use flate2::write::GzEncoder;
            use flate2::Compression;
            use std::io::Write;
            let mut enc = GzEncoder::new(Vec::new(), Compression::default());
            enc.write_all(&ts).unwrap();
            enc.finish().unwrap()
        };
        let mut rgb = b"TIKTIKPX".to_vec();
        rgb.extend_from_slice(&(gz.len() as u32).to_be_bytes());
        rgb.extend_from_slice(&gz);
        while rgb.len() % 3 != 0 {
            rgb.push(0);
        }
        let width = (rgb.len() / 3) as u32;
        let mut ihdr = Vec::new();
        ihdr.extend_from_slice(&width.to_be_bytes());
        ihdr.extend_from_slice(&1u32.to_be_bytes());
        ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
        let mut scan = vec![0u8];
        scan.extend_from_slice(&rgb);
        let idat = {
            use flate2::write::ZlibEncoder;
            use flate2::Compression;
            use std::io::Write;
            let mut enc = ZlibEncoder::new(Vec::new(), Compression::default());
            enc.write_all(&scan).unwrap();
            enc.finish().unwrap()
        };
        let mut png = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        let chunk = |typ: &[u8], data: &[u8]| {
            let mut c = Vec::new();
            c.extend_from_slice(&(data.len() as u32).to_be_bytes());
            c.extend_from_slice(typ);
            c.extend_from_slice(data);
            c.extend_from_slice(&[0, 0, 0, 0]);
            c
        };
        png.extend(chunk(b"IHDR", &ihdr));
        png.extend(chunk(b"IDAT", &idat));
        png.extend(chunk(b"IEND", b""));
        let out = strip_png_wrapper(&png);
        assert_eq!(out, ts);
    }

    #[test]
    fn strip_png_returns_payload_after_iend_without_ts() {
        let mut raw = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        raw.extend(std::iter::repeat_n(0u8, 8));
        raw.extend_from_slice(b"IEND");
        raw.extend([0, 0, 0, 0]);
        raw.extend_from_slice(b"ftypisom");
        let out = strip_png_wrapper(&raw);
        assert_eq!(&out[..8], b"ftypisom");
        assert!(!png_wraps_mpeg_ts(&raw));
    }
}
