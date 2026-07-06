use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_redirect_url, parse_bytes, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static SIZE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([\d.]+ ?[GM]B)").unwrap());

pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
) -> Option<ExtractResult> {
    let title = Html::parse_document(html)
        .select(&Selector::parse(r#"meta[name="og:title"]"#).unwrap())
        .next()
        .and_then(|el| el.value().attr("content"))
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    let bytes = SIZE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
        .and_then(parse_bytes);
    let url = build_redirect_url(mfp, "Streamtape", page_url)?;

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
