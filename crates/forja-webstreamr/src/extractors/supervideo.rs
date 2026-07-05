use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{extract_url_from_packed, extract_url_from_text};
use regex::Regex;
use std::collections::HashMap;
use std::sync::LazyLock;

static DELETED: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"'?The file was deleted|The file expired|Video is processing").unwrap()
});
static HEIGHT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\d{3,}x(\d{3,}),").unwrap());
static TITLE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<div class="download__title">([^<]+)</div>"#).unwrap()
});

const PACKED_PATTERNS: &[&str] = &[r#"sources:\[\{file:"(.*?)""#];
const FALLBACK_PATTERNS: &[&str] = &[r#""file"\s*:\s*"(https?:[^"]+)""#];

pub fn supports_host(host: &str) -> bool {
    host.contains("supervideo")
}

pub fn extract_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    if DELETED.is_match(html) {
        return None;
    }
    let playlist_url = extract_url_from_packed(html, PACKED_PATTERNS)
        .or_else(|| extract_url_from_text(html, FALLBACK_PATTERNS))?;
    let height = HEIGHT_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());
    let title = TITLE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty());

    let mut request_headers = HashMap::new();
    request_headers.insert("Referer".into(), "https://supervideo.cc/".into());

    Some(ExtractResult {
        url: playlist_url,
        format: StreamFormat::Hls,
        title,
        height,
        yt_id: None,
        request_headers: Some(request_headers),
    })
}
