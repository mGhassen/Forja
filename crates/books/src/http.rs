use std::collections::HashMap;

use stremio_core::fetch_get_with_headers;

pub const BASE_URL: &str = "https://libgen.li";

pub const DEFAULT_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

pub fn default_headers() -> HashMap<String, String> {
    HashMap::from([
        ("User-Agent".into(), DEFAULT_UA.into()),
        (
            "Accept".into(),
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8".into(),
        ),
        ("Accept-Language".into(), "en-US,en;q=0.5".into()),
    ])
}

pub fn fetch_html(url: &str, headers: &HashMap<String, String>, timeout_secs: u64) -> Result<String, String> {
    match fetch_get_with_headers(url, timeout_secs.max(1), headers) {
        Ok(resp) if resp.status == 200 => Ok(resp.body),
        Ok(resp) => Err(format!("HTTP {}", resp.status)),
        Err(e) => Err(e),
    }
}
