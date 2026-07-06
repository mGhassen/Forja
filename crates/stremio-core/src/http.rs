use serde::Serialize;
use std::collections::HashMap;
use std::time::Duration;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct HttpResponse {
    pub status: u16,
    pub body: String,
}

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
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }
    let rt = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
    rt.block_on(async {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(timeout_secs.max(1)))
            .redirect(reqwest::redirect::Policy::limited(8))
            .build()
            .map_err(|e| e.to_string())?;
        let mut req = if let Some(body) = body {
            client.post(url).body(body.to_string())
        } else {
            client.get(url)
        };
        for (k, v) in headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        let body = resp.text().await.map_err(|e| e.to_string())?;
        Ok(HttpResponse { status, body })
    })
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
}
