use serde::Serialize;
use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct HttpResponse {
    pub status: u16,
    pub body: String,
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("stremio-core tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("stremio-core http client")
});

pub fn fetch_get(url: &str, timeout_secs: u64) -> Result<HttpResponse, String> {
    fetch_get_with_headers(url, timeout_secs, &HashMap::new())
}

pub fn fetch_get_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
) -> Result<HttpResponse, String> {
    fetch_with_headers(url, timeout_secs, headers, None)
}

pub fn fetch_post_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: &str,
) -> Result<HttpResponse, String> {
    fetch_with_headers(url, timeout_secs, headers, Some(body))
}

fn fetch_with_headers(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: Option<&str>,
) -> Result<HttpResponse, String> {
    RUNTIME.block_on(async {
        utils::engine_cancel::with_cancel(async {
            fetch_with_headers_async(url, timeout_secs, headers, body).await
        })
        .await
    })
}

/// Catalog/metadata HTTP — not tied to playback [engine_cancel::request].
pub fn fetch_post_with_headers_unchecked(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: &str,
) -> Result<HttpResponse, String> {
    RUNTIME.block_on(fetch_with_headers_async(
        url,
        timeout_secs,
        headers,
        Some(body),
    ))
}

async fn fetch_with_headers_async(
    url: &str,
    timeout_secs: u64,
    headers: &HashMap<String, String>,
    body: Option<&str>,
) -> Result<HttpResponse, String> {
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }
    let timeout = Duration::from_secs(timeout_secs.max(1));
    let client = CLIENT.clone();
    let mut req = if let Some(body) = body {
        client.post(url).body(body.to_string())
    } else {
        client.get(url)
    };
    req = req.timeout(timeout);
    for (k, v) in headers {
        req = req.header(k.as_str(), v.as_str());
    }
    let resp = req.send().await.map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let body = resp.text().await.map_err(|e| e.to_string())?;
    Ok(HttpResponse { status, body })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_url() {
        assert!(fetch_get("", 5).is_err());
    }

    #[test]
    fn rejects_non_http_url() {
        assert!(fetch_get("ftp://example.com", 5).is_err());
    }

    #[test]
    fn fetches_torrentio_streams() {
        let resp =
            fetch_get("https://torrentio.strem.fun/stream/movie/tt0114709.json", 15).unwrap();
        assert_eq!(resp.status, 200);
        assert!(resp.body.contains("\"streams\""));
    }

    #[test]
    fn post_with_headers_reuses_shared_client() {
        let mut headers = HashMap::new();
        headers.insert("Content-Type".into(), "application/json".into());
        let body = r#"{"query":"query { Page(page: 1, perPage: 1) { media(sort: TRENDING_DESC, type: ANIME) { id } } }"}"#;
        let resp = fetch_post_with_headers("https://graphql.anilist.co", 15, &headers, body)
            .unwrap();
        assert_eq!(resp.status, 200);
        assert!(resp.body.contains("\"data\""));
    }
}
