use axum::{
    extract::{RawQuery, State},
    http::{header, StatusCode},
    response::Response,
};

use crate::ProxyState;

pub fn build_comic_proxy_url(proxy_base: &str, url: &str) -> String {
    format!(
        "{proxy_base}/comic-proxy?url={}",
        urlencoding::encode(url)
    )
}

fn comic_target_url(raw: Option<&str>) -> Option<String> {
    let query = raw?;
    let rest = query.strip_prefix("url=")?;
    urlencoding::decode(rest)
        .ok()
        .map(|s| s.into_owned())
}

fn comic_referer(target_url: &str) -> &'static str {
    if let Ok(uri) = url::Url::parse(target_url) {
        let host = uri.host_str().unwrap_or("");
        if host.contains("readcomicsonline.ru") {
            return "https://readcomicsonline.ru/";
        }
        if host.contains("readcomiconline.li") {
            return "https://readcomiconline.li/";
        }
    }
    "https://rcostation.xyz/"
}

pub async fn comic_proxy_handler(
    State(state): State<ProxyState>,
    RawQuery(query): RawQuery,
) -> Result<Response, StatusCode> {
    let target_url = comic_target_url(query.as_deref()).ok_or(StatusCode::NOT_FOUND)?;
    let referer = comic_referer(&target_url);

    let resp = state
        .client
        .get(&target_url)
        .header(
            header::USER_AGENT,
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
        )
        .header(header::REFERER, referer)
        .header(
            header::ACCEPT,
            "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        )
        .header(header::ACCEPT_LANGUAGE, "en-US,en;q=0.9")
        .header(header::ACCEPT_ENCODING, "gzip, deflate, br")
        .header(header::CONNECTION, "keep-alive")
        .header("Sec-Fetch-Dest", "image")
        .header("Sec-Fetch-Mode", "no-cors")
        .header("Sec-Fetch-Site", "cross-site")
        .send()
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?;

    let status = resp.status();
    if !status.is_success() {
        let body = resp.text().await.unwrap_or_default();
        return Ok(Response::builder()
            .status(status)
            .body(axum::body::Body::from(body))
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?);
    }

    let content_type = resp
        .headers()
        .get(header::CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("image/jpeg")
        .to_string();
    let bytes = resp.bytes().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    Ok(Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type.as_str())
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .header(header::CACHE_CONTROL, "public, max-age=86400")
        .body(axum::body::Body::from(bytes))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?)
}
