use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TraktHttpResponse {
    pub status: u16,
    pub body: String,
    pub retry_after: Option<u64>,
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("trakt-core tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("trakt-core http client")
});

fn trakt_headers(client_id: &str, access_token: Option<&str>) -> HashMap<String, String> {
    let mut headers = HashMap::new();
    headers.insert("Content-Type".into(), "application/json".into());
    headers.insert("trakt-api-version".into(), "2".into());
    headers.insert("trakt-api-key".into(), client_id.to_string());
    if let Some(token) = access_token {
        headers.insert("Authorization".into(), format!("Bearer {token}"));
    }
    headers
}

fn fetch(
    method: &str,
    url: &str,
    timeout_secs: u64,
    client_id: &str,
    access_token: Option<&str>,
    body: Option<&str>,
) -> Result<TraktHttpResponse, String> {
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }

    RUNTIME.block_on(async {
        utils::engine_cancel::with_cancel(async {
            let timeout = Duration::from_secs(timeout_secs.max(1));
            let headers = trakt_headers(client_id, access_token);
            let client = if body.is_some() || !headers.is_empty() {
                reqwest::Client::builder()
                    .timeout(timeout)
                    .redirect(reqwest::redirect::Policy::limited(8))
                    .build()
                    .map_err(|e| e.to_string())?
            } else {
                CLIENT.clone()
            };

            let mut req = match method {
                "GET" => client.get(url),
                "POST" => client.post(url),
                "DELETE" => client.delete(url),
                other => return Err(format!("unsupported method: {other}")),
            };
            req = req.timeout(timeout);
            for (k, v) in &headers {
                req = req.header(k.as_str(), v.as_str());
            }
            if let Some(body) = body {
                req = req.body(body.to_string());
            }

            let resp = req.send().await.map_err(|e| e.to_string())?;
            let status = resp.status().as_u16();
            let retry_after = resp
                .headers()
                .get("retry-after")
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.parse::<u64>().ok());
            let body = resp.text().await.map_err(|e| e.to_string())?;
            Ok(TraktHttpResponse {
                status,
                body,
                retry_after,
            })
        })
        .await
    })
}

pub fn fetch_get(
    url: &str,
    timeout_secs: u64,
    client_id: &str,
    access_token: Option<&str>,
) -> Result<TraktHttpResponse, String> {
    fetch("GET", url, timeout_secs, client_id, access_token, None)
}

pub fn fetch_post(
    url: &str,
    timeout_secs: u64,
    client_id: &str,
    access_token: Option<&str>,
    body: &str,
) -> Result<TraktHttpResponse, String> {
    fetch("POST", url, timeout_secs, client_id, access_token, Some(body))
}

pub fn fetch_delete(
    url: &str,
    timeout_secs: u64,
    client_id: &str,
    access_token: Option<&str>,
) -> Result<TraktHttpResponse, String> {
    fetch("DELETE", url, timeout_secs, client_id, access_token, None)
}
