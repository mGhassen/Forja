//! Path-style media session proxy (`/ext/{id}/…`).
//!
//! Header-protected DASH (and HLS) need a path base so relative SegmentTemplate /
//! playlist URIs resolve under the proxy with cookies — query-style `/hls-proxy`
//! cannot be a BaseURL (relative resolution drops the query).

use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, HeaderMap, Method, StatusCode},
    response::Response,
};
use std::collections::HashMap;
use std::time::Instant;

use crate::hls::{
    build_hls_upstream_request, hls_playlist_is_image_bait, rewrite_hls_playlist_relative,
};
use crate::{forward_response, parse_custom_headers, ProxyState};

const MAX_SESSIONS: usize = 48;
const SESSION_TTL_SECS: u64 = 3 * 60 * 60;

#[derive(Clone, Debug)]
pub struct ExtSession {
    /// Upstream directory with trailing `/` (SegmentTemplate / playlist relative root).
    pub base: String,
    /// Manifest file name under [base] (e.g. `index_web.mpd`).
    pub entry: String,
    pub headers: HashMap<String, String>,
    pub created: Instant,
}

/// Split `https://cdn/path/file.mpd` → (`https://cdn/path/`, `file.mpd`).
pub fn split_base_entry(url: &str) -> (String, String) {
    let no_q = url.split('?').next().unwrap_or(url);
    match no_q.rfind('/') {
        Some(i) => {
            let base = no_q[..=i].to_string();
            let entry = no_q[i + 1..].to_string();
            let entry = if entry.is_empty() {
                "index".to_string()
            } else {
                entry
            };
            (base, entry)
        }
        None => (format!("{no_q}/"), "index".to_string()),
    }
}

fn new_session_id() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{:x}", nanos ^ (nanos >> 17))
}

fn evict_stale(sessions: &mut HashMap<String, ExtSession>) {
    sessions.retain(|_, s| s.created.elapsed().as_secs() < SESSION_TTL_SECS);
    if sessions.len() < MAX_SESSIONS {
        return;
    }
    let mut ids: Vec<(String, Instant)> = sessions
        .iter()
        .map(|(id, s)| (id.clone(), s.created))
        .collect();
    ids.sort_by_key(|(_, t)| *t);
    let drop_n = sessions.len() + 1 - MAX_SESSIONS;
    for (id, _) in ids.into_iter().take(drop_n) {
        sessions.remove(&id);
    }
}

/// Create a session and return the local play URL (`http://127.0.0.1:{port}/ext/{id}/{entry}`).
pub async fn create_ext_session(
    state: &ProxyState,
    url: &str,
    headers_json: &str,
) -> Option<String> {
    let url = url.trim();
    if url.is_empty() {
        return None;
    }
    let (base, entry) = split_base_entry(url);
    let headers = parse_custom_headers(Some(headers_json));
    let id = new_session_id();
    {
        let mut sessions = state.sessions.write().await;
        evict_stale(&mut sessions);
        sessions.insert(
            id.clone(),
            ExtSession {
                base,
                entry: entry.clone(),
                headers,
                created: Instant::now(),
            },
        );
    }
    let port = *state.listen_port.read().await;
    if port == 0 {
        return None;
    }
    Some(format!("http://127.0.0.1:{port}/ext/{id}/{entry}"))
}

pub async fn ext_proxy_handler(
    State(state): State<ProxyState>,
    Path((id, path)): Path<(String, String)>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let session = {
        let sessions = state.sessions.read().await;
        sessions.get(&id).cloned()
    };
    let Some(session) = session else {
        return Err(StatusCode::NOT_FOUND);
    };

    let rel = {
        let p = path.trim_start_matches('/');
        if p.is_empty() {
            session.entry.as_str()
        } else {
            p
        }
    };
    if rel.contains("..") {
        return Err(StatusCode::BAD_REQUEST);
    }

    let target_url = format!("{}{rel}", session.base);
    let req =
        build_hls_upstream_request(&state, method.clone(), &target_url, &session.headers, &headers)?;
    let resp = req.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    let status = resp.status();
    let content_type = resp
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_lowercase();

    let looks_mpd = rel.to_ascii_lowercase().contains(".mpd")
        || content_type.contains("dash+xml")
        || content_type.contains("mpd");

    let looks_hls = content_type.contains("mpegurl")
        || content_type.contains("x-mpegurl")
        || rel.to_ascii_lowercase().contains(".m3u8")
        || rel.contains("/playlist/");

    if looks_hls {
        let body = resp.text().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        let trimmed = body.trim_start();
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
        if hls_playlist_is_image_bait(&body) {
            return Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .header(header::CONTENT_TYPE, "text/plain; charset=utf-8")
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .body(Body::from("ext-proxy: rejected image decoy playlist"))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
        let rewritten = rewrite_hls_playlist_relative(&body, &target_url, &session.base);
        return Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/vnd.apple.mpegurl")
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .body(Body::from(rewritten))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    if looks_mpd {
        let body = resp.text().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        if !status.is_success() {
            return Response::builder()
                .status(StatusCode::from_u16(status.as_u16()).unwrap_or(StatusCode::BAD_GATEWAY))
                .header(header::CONTENT_TYPE, "text/plain; charset=utf-8")
                .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
                .body(Body::from(body))
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
        }
        let rewritten = rewrite_mpd_absolute_urls(&body, &session.base);
        return Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/dash+xml")
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .header(header::ACCEPT_RANGES, "bytes")
            .header(header::CONTENT_LENGTH, rewritten.len())
            .body(Body::from(rewritten))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    forward_response(resp)
}

/// Rewrite absolute URLs under [session_base] to relative paths so players keep
/// fetching via `/ext/{id}/…`. Leaves `$Number$` templates intact.
pub fn rewrite_mpd_absolute_urls(body: &str, session_base: &str) -> String {
    if !body.contains("http://") && !body.contains("https://") {
        return body.to_string();
    }
    let mut out = body.to_string();
    for scheme in ["https://", "http://"] {
        for attr in ["media=\"", "initialization=\"", "sourceURL=\"", "value=\""] {
            let prefix = format!("{attr}{scheme}");
            let mut search = 0;
            while let Some(rel) = out[search..].find(&prefix) {
                let start = search + rel + attr.len();
                let end = match out[start..].find('"') {
                    Some(e) => e,
                    None => break,
                };
                let abs = out[start..start + end].to_string();
                if let Some(rel_path) = abs.strip_prefix(session_base) {
                    let rel_path = rel_path.to_string();
                    out.replace_range(start..start + end, &rel_path);
                    search = start + rel_path.len() + 1;
                } else {
                    search = start + end + 1;
                }
            }
        }
    }
    let mut search = 0;
    while let Some(rel) = out[search..].find("<BaseURL>") {
        let start = search + rel + "<BaseURL>".len();
        let end = match out[start..].find("</BaseURL>") {
            Some(e) => e,
            None => break,
        };
        let abs = out[start..start + end].trim().to_string();
        if abs.starts_with("http://") || abs.starts_with("https://") {
            if let Some(rel_path) = abs.strip_prefix(session_base) {
                let rel_path = rel_path.to_string();
                out.replace_range(start..start + end, &rel_path);
                search = start + rel_path.len();
                continue;
            }
            if abs.starts_with(session_base.trim_end_matches('/')) {
                out.replace_range(start..start + end, "");
                search = start;
                continue;
            }
        }
        search = start + end + 10;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_mpd_url() {
        let (base, entry) = split_base_entry("https://sacdn.example/dash/abc/index_web.mpd");
        assert_eq!(base, "https://sacdn.example/dash/abc/");
        assert_eq!(entry, "index_web.mpd");
    }

    #[test]
    fn mpd_rewrite_leaves_relative_templates() {
        let body = r#"<MPD><Representation>
				<SegmentTemplate initialization="init-stream$RepresentationID$.m4s" media="chunk-stream$RepresentationID$-$Number%05d$.m4s"/>
			</Representation></MPD>"#;
        let out = rewrite_mpd_absolute_urls(body, "https://cdn/dash/x/");
        assert!(out.contains("chunk-stream$RepresentationID$-$Number%05d$.m4s"));
        assert!(out.contains("init-stream$RepresentationID$.m4s"));
    }

    #[test]
    fn mpd_rewrite_strips_absolute_media() {
        let body = r#"media="https://cdn/dash/x/chunk-stream0-00001.m4s""#;
        let out = rewrite_mpd_absolute_urls(body, "https://cdn/dash/x/");
        assert_eq!(out, r#"media="chunk-stream0-00001.m4s""#);
    }
}
