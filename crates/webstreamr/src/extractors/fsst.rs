use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::collections::HashMap;
use std::sync::LazyLock;

static FILE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"file:"(.*)""#).unwrap());
static ENTRY_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\[?([\d]*)p?\]?(.*)").unwrap());
static TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)<title>([^<]+)</title>").unwrap());

pub fn supports_host(host: &str) -> bool {
    host.contains("fsst")
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    let file_blob = FILE_RE.captures(html)?.get(1)?.as_str();
    let last = file_blob.split(',').next_back()?;
    let entry = ENTRY_RE.captures(last)?;
    let file_href = entry.get(2)?.as_str();
    if file_href.is_empty() {
        return None;
    }
    let height = entry
        .get(1)
        .and_then(|m| m.as_str().parse::<u32>().ok())
        .filter(|h| *h > 0);
    let title = TITLE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    let mut request_headers = HashMap::new();
    if let Ok(page) = url::Url::parse(page_url) {
        if let Some(host) = page.host_str() {
            let origin = format!("{}://{}", page.scheme(), host);
            request_headers.insert("Referer".into(), format!("{origin}/"));
            request_headers.insert("Origin".into(), origin);
        }
    }

    Some(ExtractResult {
        url: file_href.to_string(),
        format: StreamFormat::Mp4,
        title,
        height,
        request_headers: if request_headers.is_empty() {
            None
        } else {
            Some(request_headers)
        },
        ..Default::default()
    })
}
