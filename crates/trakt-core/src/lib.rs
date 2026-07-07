mod http;

use serde::{Deserialize, Serialize};

pub use http::TraktHttpResponse;

pub const BASE_URL: &str = "https://api.trakt.tv";

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct TraktRequest {
    pub client_id: String,
    #[serde(default)]
    pub access_token: Option<String>,
    pub method: String,
    pub path: String,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default = "default_timeout")]
    pub timeout_secs: u64,
}

fn default_timeout() -> u64 {
    15
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct TraktResponse {
    pub status: u16,
    pub body: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retry_after: Option<u64>,
}

pub fn build_url(path: &str) -> String {
    let path = path.trim();
    if path.starts_with("http") {
        return path.to_string();
    }
    format!("{BASE_URL}/{}", path.trim_start_matches('/'))
}

pub fn request_json(request_json: &str) -> String {
    let req: TraktRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    if req.client_id.trim().is_empty() {
        return serde_json::json!({ "error": "client_id required" }).to_string();
    }

    let url = build_url(&req.path);
    let method = req.method.trim().to_uppercase();
    let body = req.body.as_deref();

    let result = match method.as_str() {
        "GET" => http::fetch_get(&url, req.timeout_secs, &req.client_id, req.access_token.as_deref()),
        "POST" => http::fetch_post(
            &url,
            req.timeout_secs,
            &req.client_id,
            req.access_token.as_deref(),
            body.unwrap_or(""),
        ),
        "DELETE" => http::fetch_delete(&url, req.timeout_secs, &req.client_id, req.access_token.as_deref()),
        other => Err(format!("unsupported method: {other}")),
    };

    match result {
        Ok(resp) => serde_json::to_string(&TraktResponse {
            status: resp.status,
            body: resp.body,
            retry_after: resp.retry_after,
        })
        .unwrap_or_else(|_| "{}".into()),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_url_relative() {
        assert_eq!(
            build_url("/sync/watchlist/movies"),
            "https://api.trakt.tv/sync/watchlist/movies"
        );
    }

    #[test]
    fn rejects_empty_client_id() {
        let raw = request_json(r#"{"client_id":"","method":"GET","path":"/users/me"}"#);
        assert!(raw.contains("client_id required"));
    }

    #[test]
    fn rejects_bad_method() {
        let raw = request_json(
            r#"{"client_id":"x","method":"PATCH","path":"/users/me","access_token":"t"}"#,
        );
        assert!(raw.contains("unsupported method"));
    }
}
