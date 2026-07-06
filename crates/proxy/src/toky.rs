use axum::{
    extract::{Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
};
use serde::Deserialize;

use crate::ProxyState;

#[derive(Debug, Deserialize)]
pub struct TokyQuery {
    pub url: String,
    pub id: Option<String>,
    pub token: Option<String>,
    pub src: Option<String>,
}

pub fn build_toky_proxy_url(
    proxy_base: &str,
    url: &str,
    id: &str,
    token: &str,
    src: &str,
) -> String {
    format!(
        "{proxy_base}/toky-proxy?url={}&id={}&token={}&src={}",
        urlencoding::encode(url),
        urlencoding::encode(id),
        urlencoding::encode(token),
        urlencoding::encode(src),
    )
}

pub async fn toky_proxy_handler(
    State(state): State<ProxyState>,
    Query(query): Query<TokyQuery>,
) -> Result<Response, StatusCode> {
    let base_uri = url::Url::parse(&query.url).map_err(|_| StatusCode::BAD_REQUEST)?;
    let decoded_path = urlencoding::decode(base_uri.path())
        .map(|s| s.into_owned())
        .unwrap_or_else(|_| base_uri.path().to_string());
    let final_url = format!("https://tokybook.com{decoded_path}");

    let final_track_src = query
        .src
        .as_ref()
        .map(|s| {
            url::Url::parse(&format!("https://tokybook.com{s}"))
                .ok()
                .map(|u| u.path().to_string())
                .unwrap_or_default()
        })
        .unwrap_or_default();

    let mut req = state
        .client
        .get(&final_url)
        .header(
            header::USER_AGENT,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
        )
        .header(header::REFERER, "https://tokybook.com/")
        .header(header::ORIGIN, "https://tokybook.com")
        .header(header::ACCEPT, "*/*")
        .header("x-track-src", final_track_src.as_str());
    if let Some(id) = &query.id {
        req = req.header("x-audiobook-id", id.as_str());
    }
    if let Some(token) = &query.token {
        req = req.header("x-stream-token", token.as_str());
    }

    let resp = req.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
    let status = resp.status();
    if !status.is_success() {
        let body = resp.text().await.unwrap_or_default();
        return Ok((status, body).into_response());
    }

    let port = *state.listen_port.read().await;
    let proxy_base = format!("http://127.0.0.1:{port}/toky-proxy");

    if query.url.ends_with(".m3u8") {
        let body = resp.text().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
        let base_dir = query
            .url
            .rsplit_once('/')
            .map(|(p, _)| format!("{p}/"))
            .unwrap_or_default();
        let base_src_dir = query
            .src
            .as_ref()
            .and_then(|s| s.rsplit_once('/').map(|(p, _)| format!("{p}/")))
            .unwrap_or_default();

        let audiobook_id = query.id.as_deref().unwrap_or("");
        let token = query.token.as_deref().unwrap_or("");

        let rewritten = body
            .lines()
            .map(|line| {
                if line.is_empty() || line.starts_with('#') {
                    return line.to_string();
                }
                let segment_url = if line.starts_with("http") {
                    line.to_string()
                } else {
                    format!("{base_dir}{line}")
                };
                let segment_src = if line.starts_with("http") {
                    line.to_string()
                } else {
                    format!("{base_src_dir}{line}")
                };
                build_toky_proxy_url(&proxy_base, &segment_url, audiobook_id, token, &segment_src)
            })
            .collect::<Vec<_>>()
            .join("\n");

        return Ok((
            [(header::CONTENT_TYPE, "application/x-mpegURL")],
            rewritten,
        )
            .into_response());
    }

    let content_type = resp
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("video/mp2t")
        .to_string();
    let bytes = resp.bytes().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type.as_str())
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .body(axum::body::Body::from(bytes))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}
