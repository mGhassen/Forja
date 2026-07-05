use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::sync::LazyLock;

static HUBCLOUD_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)href=["']([^"']+)["'][^>]*>[\s\S]*?HubCloud"#).unwrap()
});

pub fn supports_host(host: &str) -> bool {
    host.contains("hubdrive")
}

pub fn extract_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    let href = HUBCLOUD_RE.captures(html)?.get(1)?.as_str();
    Some(ExtractResult {
        url: String::new(),
        format: StreamFormat::Unknown,
        title: None,
        height: None,
        yt_id: None,
        next_url: Some(href.to_string()),
        is_external: false,
        request_headers: None,
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}
