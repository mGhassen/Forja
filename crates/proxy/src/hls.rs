use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, HeaderMap, Method, StatusCode},
    response::Response,
};
use serde::Deserialize;
use std::collections::HashMap;

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
    if raw[0] != 0x89 || raw[1] != 0x50 || raw[2] != 0x4E || raw[3] != 0x47 {
        return raw.to_vec();
    }
    let mut idx = None;
    for i in 8..raw.len().saturating_sub(8) {
        if raw[i] == 0x49
            && raw[i + 1] == 0x45
            && raw[i + 2] == 0x4E
            && raw[i + 3] == 0x44
        {
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
        let scheme = if base_path.starts_with("https://") || server_base.starts_with("https://")
        {
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

    body.lines()
        .map(|line| {
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
                        let replacement = build_hls_proxy_url(
                            proxy_base,
                            &full,
                            headers_json,
                            strip,
                        );
                        let new_token = format!("URI=\"{replacement}\"");
                        out.replace_range(start..start + 5 + end + 1, &new_token);
                        search_from = start + new_token.len();
                    }
                    return out;
                }
                return line.to_string();
            }
            let full = resolve_url(trimmed, base_path, server_base);
            build_hls_proxy_url(proxy_base, &full, headers_json, strip)
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn header_ci<'a>(
    custom_headers: &'a HashMap<String, String>,
    name: &str,
) -> Option<&'a str> {
    let want = name.to_ascii_lowercase();
    custom_headers
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(&want))
        .map(|(_, v)| v.as_str())
}

fn build_hls_upstream_request(
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

pub async fn hls_proxy_handler(
    State(state): State<ProxyState>,
    Query(query): Query<HlsProxyQuery>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let target_url = urlencoding::decode(&query.url)
        .map(|s| s.into_owned())
        .unwrap_or(query.url);
    let custom = parse_custom_headers(query.headers.as_deref());
    let headers_json = query.headers.as_deref().unwrap_or("{}");
    let strip = query.strip.as_deref();

    let req = build_hls_upstream_request(&state, method.clone(), &target_url, &custom, &headers)?;
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
        || target_url.contains(".m3u8");

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
        let port = *state.listen_port.read().await;
        let proxy_base = format!("http://127.0.0.1:{port}/hls-proxy");
        let rewritten = rewrite_hls_playlist(&body, &target_url, &proxy_base, headers_json, strip);
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
        return Response::builder()
            .status(status)
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
        assert_eq!(
            out,
            "https://hls19.videotradercdn.site/segment/x.png"
        );
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
