use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{extract_url_from_packed, extract_url_from_text};
use regex::Regex;
use std::collections::HashMap;
use url::Url;

const PACKED_PATTERNS: &[&str] = &[r#"file: ?"(.*?)""#];
const FALLBACK_PATTERNS: &[&str] = &[
    r#""file"\s*:\s*"(https?:[^"]+\.m3u8[^"]*)""#,
    r#"file\s*:\s*"(https?:[^"]+\.m3u8[^"]*)""#,
];

pub fn supports_host(host: &str) -> bool {
    host.contains("vidora")
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    let m3u8 = extract_url_from_packed(html, PACKED_PATTERNS)
        .or_else(|| extract_url_from_text(html, FALLBACK_PATTERNS))?;
    let page = Url::parse(page_url).ok()?;
    let host = page.host_str()?;
    let origin = format!("{}://{}", page.scheme(), host);

    let title = Regex::new(r"(?i)<title>(?:Watch )?([^<]+?)(?: at Vidora)?</title>")
        .ok()
        .and_then(|re| re.captures(html))
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    let mut request_headers = HashMap::new();
    request_headers.insert("Origin".into(), origin);

    Some(ExtractResult {
        url: m3u8,
        format: StreamFormat::Hls,
        title,
        height: None,
        yt_id: None,
        next_url: None,
        is_external: false,
        request_headers: Some(request_headers),
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}
