mod http;
mod introdb;
mod lyrics;
mod mdblist;
mod metadata;
mod paper2audio;
mod subtitle;

use base64::Engine;
use serde::{Deserialize, Serialize};

pub use http::AnimeHttpResponse;
pub use metadata::metadata_request_json;
pub use subtitle::subtitle_request_json;

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct AnimeRequest {
    pub url: String,
    pub method: String,
    #[serde(default)]
    pub headers_json: String,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default)]
    pub body_base64: Option<String>,
    #[serde(default)]
    pub response_binary: bool,
    #[serde(default = "default_timeout")]
    pub timeout_secs: u64,
    #[serde(default)]
    pub max_retries: u32,
}

fn default_timeout() -> u64 {
    15
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct AnimeResponse {
    pub status: u16,
    pub body: String,
    #[serde(default)]
    pub body_base64: String,
    #[serde(default)]
    pub headers: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub final_url: String,
}

pub fn request_json(request_json: &str) -> String {
    let req: AnimeRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    if req.url.trim().is_empty() {
        return serde_json::json!({ "error": "url required" }).to_string();
    }

    let headers: std::collections::HashMap<String, String> =
        serde_json::from_str(&req.headers_json).unwrap_or_default();
    let method = req.method.trim().to_uppercase();

    let body_bytes = match req.body_base64.as_deref() {
        Some(b64) if !b64.is_empty() => {
            match base64::engine::general_purpose::STANDARD.decode(b64) {
                Ok(v) => Some(v),
                Err(e) => {
                    return serde_json::json!({ "error": format!("invalid body_base64: {e}") })
                        .to_string();
                }
            }
        }
        _ => None,
    };

    match http::fetch_with_retries(
        &method,
        &req.url,
        &headers,
        req.body.as_deref(),
        body_bytes.as_deref(),
        req.response_binary,
        req.timeout_secs,
        req.max_retries,
    ) {
        Ok(resp) => serde_json::to_string(&AnimeResponse {
            status: resp.status,
            body: resp.body,
            body_base64: resp.body_base64,
            headers: resp.headers,
            final_url: resp.final_url,
        })
        .unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_url() {
        let raw = request_json(r#"{"url":"","method":"GET"}"#);
        assert!(raw.contains("url required"));
    }
}
