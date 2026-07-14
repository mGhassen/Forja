mod http;

use serde::{Deserialize, Serialize};

pub use http::JellyfinHttpResponse;

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct JellyfinRequest {
    pub base_url: String,
    pub method: String,
    pub path: String,
    pub authorization: String,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default = "default_timeout")]
    pub timeout_secs: u64,
    #[serde(default)]
    pub max_retries: u32,
}

fn default_timeout() -> u64 {
    30
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct JellyfinResponse {
    pub status: u16,
    pub body: String,
}

pub fn build_url(base_url: &str, path: &str) -> String {
    let base = base_url.trim().trim_end_matches('/');
    let path = path.trim();
    if path.starts_with("http://") || path.starts_with("https://") {
        return path.to_string();
    }
    let path = path.trim_start_matches('/');
    format!("{base}/{path}")
}

pub fn request_json(request_json: &str) -> String {
    let req: JellyfinRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    if req.base_url.trim().is_empty() {
        return serde_json::json!({ "error": "base_url required" }).to_string();
    }
    if req.authorization.trim().is_empty() {
        return serde_json::json!({ "error": "authorization required" }).to_string();
    }

    let url = build_url(&req.base_url, &req.path);
    let method = req.method.trim().to_uppercase();
    let body = req.body.as_deref();

    match http::fetch_with_retries(
        &method,
        &url,
        &req.authorization,
        body,
        req.timeout_secs,
        req.max_retries,
    ) {
        Ok(resp) => serde_json::to_string(&JellyfinResponse {
            status: resp.status,
            body: resp.body,
        })
        .unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_url_joins_base_and_path() {
        assert_eq!(
            build_url("https://jf.local/", "/Users/Me"),
            "https://jf.local/Users/Me"
        );
    }

    #[test]
    fn rejects_empty_base_url() {
        let raw = request_json(
            r#"{"base_url":"","method":"GET","path":"/Users/Me","authorization":"x"}"#,
        );
        assert!(raw.contains("base_url required"));
    }
}
