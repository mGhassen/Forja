use axum::{
    body::Body,
    extract::{Query, State},
    http::{header, HeaderMap, Method, StatusCode},
    response::Response,
};
use serde::Deserialize;

use crate::{forward_response, ProxyState};

#[derive(Debug, Deserialize)]
pub struct JellyfinQuery {
    pub url: String,
    pub auth: String,
}

pub fn build_jellyfin_proxy_url(proxy_base: &str, target_url: &str, auth: &str) -> String {
    format!(
        "{proxy_base}/jellyfin-stream?url={}&auth={}",
        urlencoding::encode(target_url),
        urlencoding::encode(auth),
    )
}

pub async fn jellyfin_stream_handler(
    State(state): State<ProxyState>,
    Query(query): Query<JellyfinQuery>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let decoded_url = urlencoding::decode(&query.url)
        .map(|s| s.into_owned())
        .unwrap_or(query.url);
    let auth_header = urlencoding::decode(&query.auth)
        .map(|s| s.into_owned())
        .unwrap_or(query.auth);

    let target_uri = url::Url::parse(&decoded_url).map_err(|_| StatusCode::BAD_REQUEST)?;
    let server_base = format!(
        "{}://{}{}",
        target_uri.scheme(),
        target_uri.host_str().unwrap_or(""),
        target_uri
            .port()
            .map(|p| format!(":{p}"))
            .unwrap_or_default()
    );

    let mut req = state.client.request(method.clone(), decoded_url.as_str());
    req = req.header("X-Emby-Authorization", &auth_header);
    req = req.header(
        header::USER_AGENT,
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    );
    req = req.header(header::ACCEPT, "*/*");
    req = req.header(header::CONNECTION, "keep-alive");
    if let Some(range) = headers.get(header::RANGE) {
        req = req.header(header::RANGE, range);
    }

    let resp = req.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
    let content_type = resp
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .to_lowercase();

    let is_hls = content_type.contains("mpegurl")
        || content_type.contains("x-mpegurl")
        || decoded_url.contains(".m3u8");

    if is_hls {
        let body = resp.text().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        let base_path = decoded_url
            .rsplit_once('/')
            .map(|(p, _)| format!("{p}/"))
            .unwrap_or_default();
        let port = *state.listen_port.read().await;
        let proxy_base = format!("http://127.0.0.1:{port}/jellyfin-stream");

        let rewritten = body
            .lines()
            .map(|line| {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with('#') {
                    if trimmed.contains("URI=\"") {
                        let re = regex::Regex::new(r#"URI="([^"]+)""#).unwrap();
                        return re
                            .replace_all(trimmed, |caps: &regex::Captures| {
                                let uri = &caps[1];
                                let full_uri = resolve_jellyfin_url(uri, &base_path, &server_base);
                                format!(
                                    "URI=\"{}\"",
                                    build_jellyfin_proxy_url(&proxy_base, &full_uri, &auth_header)
                                )
                            })
                            .into_owned();
                    }
                    return line.to_string();
                }
                let full_url = resolve_jellyfin_url(trimmed, &base_path, &server_base);
                build_jellyfin_proxy_url(&proxy_base, &full_url, &auth_header)
            })
            .collect::<Vec<_>>()
            .join("\n");

        return Response::builder()
            .status(StatusCode::OK)
            .header(header::CONTENT_TYPE, "application/vnd.apple.mpegurl")
            .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
            .body(Body::from(rewritten))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR);
    }

    forward_response(resp)
}

fn resolve_jellyfin_url(relative: &str, base_path: &str, server_base: &str) -> String {
    if relative.starts_with("http://") || relative.starts_with("https://") {
        relative.to_string()
    } else if relative.starts_with('/') {
        format!("{server_base}{relative}")
    } else {
        format!("{base_path}{relative}")
    }
}
