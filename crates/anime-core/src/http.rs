use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use base64::Engine;
use tokio::runtime::Runtime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AnimeHttpResponse {
    pub status: u16,
    pub body: String,
    pub body_base64: String,
    pub headers: HashMap<String, String>,
    pub final_url: String,
}

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("anime-core tokio runtime"));

fn client(timeout: Duration) -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(15))
        .build()
        .map_err(|e| e.to_string())
}

async fn fetch_once(
    method: &str,
    url: &str,
    headers: &HashMap<String, String>,
    body: Option<&str>,
    body_bytes: Option<&[u8]>,
    response_binary: bool,
    timeout: Duration,
) -> Result<AnimeHttpResponse, String> {
    let url = url.trim();
    if !url.starts_with("http") {
        return Err("Invalid URL".into());
    }

    let client = client(timeout)?;
    let mut req = match method {
        "GET" => client.get(url),
        "POST" => client.post(url),
        "HEAD" => client.head(url),
        other => return Err(format!("unsupported method: {other}")),
    };

    for (k, v) in headers {
        req = req.header(k.as_str(), v.as_str());
    }
    if let Some(bytes) = body_bytes {
        req = req.body(bytes.to_vec());
    } else if let Some(body) = body {
        req = req.body(body.to_string());
    }

    let resp = req.send().await.map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let final_url = resp.url().to_string();
    let mut resp_headers = HashMap::new();
    for (name, value) in resp.headers() {
        if let Ok(v) = value.to_str() {
            resp_headers.insert(name.as_str().to_ascii_lowercase(), v.to_string());
        }
    }

    let (body, body_base64) = if method == "HEAD" {
        (String::new(), String::new())
    } else if response_binary {
        let bytes = resp.bytes().await.map_err(|e| e.to_string())?;
        (
            String::new(),
            base64::engine::general_purpose::STANDARD.encode(bytes),
        )
    } else {
        (
            resp.text().await.map_err(|e| e.to_string())?,
            String::new(),
        )
    };

    Ok(AnimeHttpResponse {
        status,
        body,
        body_base64,
        headers: resp_headers,
        final_url,
    })
}

pub fn fetch_with_retries(
    method: &str,
    url: &str,
    headers: &HashMap<String, String>,
    body: Option<&str>,
    body_bytes: Option<&[u8]>,
    response_binary: bool,
    timeout_secs: u64,
    max_retries: u32,
) -> Result<AnimeHttpResponse, String> {
    let timeout = Duration::from_secs(timeout_secs.max(1));
    let mut last_error = String::from("Request failed");

    RUNTIME.block_on(async {
        utils::engine_cancel::with_cancel(async {
            for attempt in 0..=max_retries {
                if attempt > 0 {
                    let delay = Duration::from_millis(300 * (1u64 << (attempt - 1)));
                    tokio::time::sleep(delay).await;
                }
                match fetch_once(
                    method,
                    url,
                    headers,
                    body,
                    body_bytes,
                    response_binary,
                    timeout,
                )
                .await
                {
                    Ok(resp) => return Ok(resp),
                    Err(e) => last_error = e,
                }
            }
            Err(last_error)
        })
        .await
    })
}
