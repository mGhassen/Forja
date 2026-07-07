use std::collections::HashMap;

use stremio_core::fetch_get_with_headers;

/// GET HTML/text from a URL with optional headers JSON object.
/// On HTTP 200 returns the response body. Otherwise `{"error":"..."}`.
pub fn fetch_html(url: &str, headers_json: &str, timeout_secs: u64) -> String {
    let headers: HashMap<String, String> =
        serde_json::from_str(headers_json).unwrap_or_default();

    match fetch_get_with_headers(url, timeout_secs.max(1), &headers) {
        Ok(resp) if resp.status == 200 => resp.body,
        Ok(resp) => serde_json::json!({
            "error": format!("HTTP {}", resp.status),
            "status": resp.status,
        })
        .to_string(),
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_url() {
        let raw = fetch_html("not-a-url", "{}", 10);
        assert!(raw.contains("error"));
    }
}
