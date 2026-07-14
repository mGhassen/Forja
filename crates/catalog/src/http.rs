use std::collections::HashMap;

use stremio::fetch_get_with_headers;

pub const BASE_URL: &str = "https://bestsimilar.com";

pub const DEFAULT_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

pub fn default_html_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml".into(),
        ),
        ("Referer".into(), format!("{BASE_URL}/")),
    ])
}

pub fn autocomplete_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        ("Accept".into(), "application/json".into()),
        ("X-Requested-With".into(), "XMLHttpRequest".into()),
        ("Referer".into(), format!("{BASE_URL}/")),
    ])
}

pub fn fetch_html(url: &str, headers: &HashMap<String, String>, timeout_secs: u64) -> Result<String, String> {
    match fetch_get_with_headers(url, timeout_secs.max(1), headers) {
        Ok(resp) if resp.status == 200 => Ok(resp.body),
        Ok(resp) => Err(format!("HTTP {}", resp.status)),
        Err(e) => Err(e),
    }
}
