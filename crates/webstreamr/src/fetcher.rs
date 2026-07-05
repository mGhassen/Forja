//! HTTP client for webstreamr source/extractor fetches.

use std::collections::HashMap;
use std::time::Duration;

#[derive(Debug, Clone)]
pub struct FetchConfig {
    pub headers: HashMap<String, String>,
    pub timeout: Duration,
}

impl Default for FetchConfig {
    fn default() -> Self {
        Self {
            headers: HashMap::new(),
            timeout: Duration::from_secs(20),
        }
    }
}

pub fn fetch_text(url: &str, config: &FetchConfig) -> Result<String, String> {
    let client = reqwest::blocking::Client::builder()
        .timeout(config.timeout)
        .redirect(reqwest::redirect::Policy::limited(5))
        .build()
        .map_err(|e| e.to_string())?;
    let mut req = client.get(url);
    for (k, v) in &config.headers {
        req = req.header(k.as_str(), v.as_str());
    }
    req.send()
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?
        .text()
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use wiremock::matchers::{method, path};
    use wiremock::{Mock, MockServer, ResponseTemplate};

    #[tokio::test]
    async fn fetch_text_gets_body() {
        let server = MockServer::start().await;
        Mock::given(method("GET"))
            .and(path("/page"))
            .respond_with(ResponseTemplate::new(200).set_body_string("<html>ok</html>"))
            .mount(&server)
            .await;

        let url = format!("{}/page", server.uri());
        let body = tokio::task::spawn_blocking(move || fetch_text(&url, &FetchConfig::default()))
            .await
            .unwrap()
            .unwrap();
        assert!(body.contains("ok"));
    }
}
