use crate::types::ExtractResult;
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
        next_url: Some(href.to_string()),
        ..Default::default()
    })
}
