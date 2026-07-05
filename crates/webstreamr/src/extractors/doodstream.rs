use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_redirect_url, parse_bytes, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static NOT_FOUND: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"Video not found").unwrap());
static SIZE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([\d.]+ ?[GM]B)").unwrap());
static TITLE_SUFFIX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r" - DoodStream$").unwrap());

pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
    download_html: &str,
) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let title = Html::parse_document(html)
        .select(&Selector::parse("title").unwrap())
        .next()
        .map(|el| {
            TITLE_SUFFIX
                .replace(el.text().collect::<String>().trim(), "")
                .trim()
                .to_string()
        })
        .filter(|s| !s.is_empty());
    let bytes = SIZE_RE
        .captures(download_html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
        .and_then(|s| parse_bytes(s));
    let url = build_redirect_url(mfp, "Doodstream", page_url)?;

    Some(ExtractResult {
        url,
        format: StreamFormat::Mp4,
        title,
        height: None,
        yt_id: None,
        next_url: None,
        is_external: false,
        request_headers: None,
        label: None,
        bytes,
        meta_extractor_id: None,
    })
}
