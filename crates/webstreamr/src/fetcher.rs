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
        // MegaKino domain chain alone is ~13 hops; keep headroom for others.
        .redirect(reqwest::redirect::Policy::limited(25))
        .cookie_store(true)
        .user_agent(DEFAULT_USER_AGENT)
        .build()
        .expect("webstreamr http client")
});

fn client_for(config: &FetchConfig) -> Result<reqwest::Client, String> {
    // Always use the shared cookie-aware client so MegaKino-style
    // token cookies survive across HEAD → POST → GET.
    let _ = config;
    Ok(CLIENT.clone())
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
    // Manual redirect walk: HEAD with followRedirects=false and walk
    // Location hop-by-hop. MegaKino alone needs ~13 hops; reqwest's
    // limited(10) policy dies mid-chain with "error following redirect".
    utils::engine_cancel::with_cancel(async {
        let client = reqwest::Client::builder()
            .timeout(config.timeout)
            .redirect(reqwest::redirect::Policy::none())
            .cookie_store(true)
            .user_agent(DEFAULT_USER_AGENT)
            .build()
            .map_err(|e| e.to_string())?;
        let mut current = url.to_string();
        for _ in 0..40 {
            let mut req = client.head(&current);
            for (k, v) in &config.headers {
                req = req.header(k.as_str(), v.as_str());
            }
            let resp = req.send().await.map_err(|e| e.to_string())?;
            let status = resp.status().as_u16();
            if (300..400).contains(&status) {
                let Some(loc) = resp
                    .headers()
                    .get(reqwest::header::LOCATION)
                    .and_then(|v| v.to_str().ok())
                    .map(|s| s.to_string())
                else {
                    return Ok(current);
                };
                current = if loc.starts_with("http") {
                    loc
                } else {
                    url::Url::parse(&current)
                        .ok()
                        .and_then(|b| b.join(&loc).ok())
                        .map(|u| u.to_string())
                        .unwrap_or(loc)
                };
                continue;
            }
            return Ok(resp.url().to_string());
        }
        Ok(current)
    })
    .await
}

async fn fetch_head_async(url: &str, config: &FetchConfig) -> Result<(), String> {
    utils::engine_cancel::with_cancel(async {
        let client = client_for(config)?;
        let mut req = client.head(url);
        for (k, v) in &config.headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let _ = req
            .send()
            .await
            .map_err(|e| e.to_string())?
            .error_for_status()
            .map_err(|e| e.to_string())?;
        Ok(())
    })
    .await
}

async fn fetch_status_body_async(
    url: &str,
    config: &FetchConfig,
) -> Result<(u16, String), String> {
    utils::engine_cancel::with_cancel(async {
        let client = client_for(config)?;
        let mut req = client.get(url);
        for (k, v) in &config.headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        let status = resp.status().as_u16();
        let text = resp.text().await.map_err(|e| e.to_string())?;
        Ok((status, text))
    })
    .await
}

pub fn fetch_text(url: &str, config: &FetchConfig) -> Result<String, String> {
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message());
    }
    RUNTIME.block_on(fetch_text_async(url, config))
}

/// GET without treating 4xx/5xx as hard errors — for playability probes.
pub fn fetch_status_body(url: &str, config: &FetchConfig) -> Result<(u16, String), String> {
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message());
    }
    RUNTIME.block_on(fetch_status_body_async(url, config))
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

/// HEAD request — used to seed cookies (e.g. MegaKino `?yg=token`).
pub fn fetch_head(url: &str, config: &FetchConfig) -> Result<(), String> {
    if utils::engine_cancel::is_requested() {
        return Err(utils::engine_cancel::cancelled_message());
    }
    RUNTIME.block_on(fetch_head_async(url, config))
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
