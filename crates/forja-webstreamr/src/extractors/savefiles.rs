use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::sync::LazyLock;

static LOCKED: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)file was locked|file was deleted").unwrap()
});
static FILE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"file:"(.*?)""#).unwrap());
static HEIGHT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\[\d{3,}x(\d{3,})").unwrap());
static TITLE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<div class="download-title">([^<]+)</div>"#).unwrap()
});

pub fn supports_host(host: &str) -> bool {
    Regex::new(r"savefiles|streamhls")
        .unwrap()
        .is_match(host)
}

pub fn extract_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    if LOCKED.is_match(html) {
        return None;
    }
    let url = FILE_RE.captures(html)?.get(1)?.as_str().to_string();
    let height = HEIGHT_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());
    let title = TITLE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    Some(ExtractResult {
        url,
        format: StreamFormat::Hls,
        title,
        height,
        ..Default::default()
    })
}
