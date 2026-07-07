use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JellyfinHttpResponse {
    pub status: u16,
    pub body: String,
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("jellyfin-core tokio runtime"));

fn client(timeout: Duration) -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(5))
        .danger_accept_invalid_certs(true)
        .build()
        .map_err(|e| e.to_string())
}

async fn fetch_once(
    method: &str,
    url: &str,
    authorization: &str,
    body: Option<&str>,
    timeout: Duration,
) -> Result<JellyfinHttpResponse, String> {
    let client = client(timeout)?;
    let mut req = match method {
        "GET" => client.get(url),
        "POST" => client.post(url),
        "DELETE" => client.delete(url),
        "HEAD" => client.head(url),
        other => return Err(format!("unsupported method: {other}")),
    };

    req = req
        .header("X-Emby-Authorization", authorization)
        .header("Content-Type", "application/json");

    if let Some(body) = body {
        req = req.body(body.to_string());
    }

    let resp = req.send().await.map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let body = if method == "HEAD" {
        String::new()
    } else {
        resp.text().await.map_err(|e| e.to_string())?
    };

    Ok(JellyfinHttpResponse { status, body })
}

pub fn fetch_with_retries(
    method: &str,
    url: &str,
    authorization: &str,
    body: Option<&str>,
    timeout_secs: u64,
    max_retries: u32,
) -> Result<JellyfinHttpResponse, String> {
    let url = url.trim();
    if url.is_empty() || !url.starts_with("http") {
        return Err("Invalid URL".into());
    }

    let timeout = Duration::from_secs(timeout_secs.max(1));
    let mut last_error = String::from("Request failed");

    RUNTIME.block_on(async {
        utils::engine_cancel::with_cancel(async {
            for attempt in 0..=max_retries {
                if attempt > 0 {
                    let delay = Duration::from_millis(300 * (1u64 << (attempt - 1)));
                    tokio::time::sleep(delay).await;
                }

                match fetch_once(method, url, authorization, body, timeout).await {
                    Ok(resp) => return Ok(resp),
                    Err(e) => {
                        last_error = e;
                    }
                }
            }
            Err(last_error)
        })
        .await
    })
}
