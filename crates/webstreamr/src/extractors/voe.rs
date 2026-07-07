use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_stream_url, parse_bytes, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static REDIRECT_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"window\.location\.href\s*=\s*'([^']+)'").unwrap()
});
static NOT_FOUND: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"An error occurred during encoding").unwrap());
static HEIGHT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"<b>(\d{3,})p</b>").unwrap());
static SIZE_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[\d.]+ ?[GM]B").unwrap());
static TITLE_PREFIX: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"^Watch ").unwrap());
static TITLE_SUFFIX: LazyLock<Regex> = LazyLock::new(|| Regex::new(r" at VOE$").unwrap());

pub fn extract_redirect_from_html(html: &str, _page_url: &str) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let dest = REDIRECT_RE.captures(html)?.get(1)?.as_str();
    Some(ExtractResult {
        url: String::new(),
        format: StreamFormat::Unknown,
        title: None,
        height: None,
        yt_id: None,
        next_url: Some(dest.to_string()),
        is_external: false,
        request_headers: None,
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}

pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) || REDIRECT_RE.is_match(html) {
        return None;
    }
    let title = Html::parse_document(html)
        .select(&Selector::parse(r#"meta[name="description"]"#).unwrap())
        .next()
        .and_then(|el| el.value().attr("content"))
        .map(|s| {
            TITLE_SUFFIX
                .replace(&TITLE_PREFIX.replace(s.trim(), ""), "")
                .trim()
                .to_string()
        })
        .filter(|s| !s.is_empty());
    let bytes = SIZE_RE
        .find_iter(html)
        .last()
        .and_then(|m| parse_bytes(m.as_str()))
        .filter(|b| *b > 16_777_216);
    let height = HEIGHT_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());
    let url = build_stream_url(mfp, "Voe", page_url)?;

    Some(ExtractResult {
        url,
        format: StreamFormat::Hls,
        title,
        height,
        yt_id: None,
        next_url: None,
        is_external: false,
        request_headers: None,
        label: None,
        bytes,
        meta_extractor_id: None,
    })
}
