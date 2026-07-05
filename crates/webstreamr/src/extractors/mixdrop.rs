use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_redirect_url, parse_bytes, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static NOT_FOUND: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)can't find the (file|video)").unwrap());
static SIZE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([\d.,]+ ?[GM]B)").unwrap());

pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let title = Html::parse_document(html)
        .select(&Selector::parse(".title b").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .filter(|s| !s.is_empty());
    let bytes = SIZE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().replace(',', ""))
        .and_then(|s| parse_bytes(&s));
    let url = build_redirect_url(mfp, "Mixdrop", page_url)?;

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
