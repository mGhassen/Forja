mod catalog;
mod http;
mod parse;

use serde_json::json;

pub use catalog::catalog_json;
pub use parse::{MangaCard, MangaChapterOut, MangaDetails};

/// Legacy fetch-only API — prefer `catalog_json` for fetch+parse.
pub fn fetch_html(url: &str, headers_json: &str, timeout_secs: u64) -> String {
    let headers: std::collections::HashMap<String, String> =
        serde_json::from_str(headers_json).unwrap_or_default();

    match http::fetch_html(url, &headers, timeout_secs) {
        Ok(body) => body,
        Err(e) => json!({ "error": e }).to_string(),
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
