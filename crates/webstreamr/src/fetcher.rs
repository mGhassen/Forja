//! HTTP client for webstreamr source/extractor fetches.

use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

#[derive(Debug, Clone)]
pub struct FetchConfig {
    pub headers: HashMap<String, String>,
    pub timeout: Duration,
}

pub const DEFAULT_USER_AGENT: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

impl Default for FetchConfig {
    fn default() -> Self {
        Self {
            headers: HashMap::from([("User-Agent".into(), DEFAULT_USER_AGENT.into())]),
            timeout: Duration::from_secs(20),
        }
    }
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("webstreamr tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .redirect(reqwest::redirect::Policy::limited(10))
        .user_agent(DEFAULT_USER_AGENT)
        .build()
        .expect("webstreamr http client")
});

fn client_for(config: &FetchConfig) -> Result<reqwest::Client, String> {
    if config.timeout == Duration::from_secs(20)
        && config.headers.len() == 1
        && config.headers.get("User-Agent").map(String::as_str) == Some(DEFAULT_USER_AGENT)
    {
        return Ok(CLIENT.clone());
    }
    reqwest::Client::builder()
        .timeout(config.timeout)
        .redirect(reqwest::redirect::Policy::limited(5))
        .build()
        .map_err(|e| e.to_string())
}

async fn fetch_text_async(url: &str, config: &FetchConfig) -> Result<String, String> {
    utils::engine_cancel::with_cancel(async {
        let client = client_for(config)?;
        let mut req = client.get(url);
        for (k, v) in &config.headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let text = req
            .send()
            .await
            .map_err(|e| e.to_string())?
            .error_for_status()
            .map_err(|e| e.to_string())?
            .text()
            .await
            .map_err(|e| e.to_string())?;
        Ok(text)
    })
    .await
}

async fn fetch_text_post_async(
    url: &str,
    body: &str,
    config: &FetchConfig,
) -> Result<String, String> {
    utils::engine_cancel::with_cancel(async {
        let client = client_for(config)?;
        let mut req = client.post(url).body(body.to_string());
        for (k, v) in &config.headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let text = req
            .send()
            .await
            .map_err(|e| e.to_string())?
            .error_for_status()
            .map_err(|e| e.to_string())?
            .text()
            .await
            .map_err(|e| e.to_string())?;
        Ok(text)
    })
    .await
}

async fn final_redirect_url_async(url: &str, config: &FetchConfig) -> Result<String, String> {
    utils::engine_cancel::with_cancel(async {
        let client = client_for(config)?;
        let mut req = client.get(url);
        for (k, v) in &config.headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        Ok(resp.url().to_string())
    })
    .await
}

pub fn fetch_text(url: &str, config: &FetchConfig) -> Result<String, String> {
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message());
    }
    RUNTIME.block_on(fetch_text_async(url, config))
}

pub fn fetch_text_post(url: &str, body: &str, config: &FetchConfig) -> Result<String, String> {
    RUNTIME.block_on(fetch_text_post_async(url, body, config))
}

pub fn fetch_json(url: &str, config: &FetchConfig) -> Result<serde_json::Value, String> {
    let text = fetch_text(url, config)?;
    serde_json::from_str(&text).map_err(|e| e.to_string())
}

pub fn final_redirect_url(url: &str, config: &FetchConfig) -> Result<String, String> {
    RUNTIME.block_on(final_redirect_url_async(url, config))
}

#[cfg(test)]
mod tests {
    use super::*;
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    #[test]
    fn fetch_text_gets_body() {
        std::thread::spawn(|| {
            let rt = Runtime::new().unwrap();
            rt.block_on(async {
                let server = MockServer::start().await;
                Mock::given(method("GET"))
                    .and(path("/page"))
                    .respond_with(ResponseTemplate::new(200).set_body_string("<html>ok</html>"))
                    .mount(&server)
                    .await;
                let url = format!("{}/page", server.uri());
                let body = fetch_text_async(&url, &FetchConfig::default())
                    .await
                    .unwrap();
                assert!(body.contains("ok"));
            });
        })
        .join()
        .unwrap();
    }
}
