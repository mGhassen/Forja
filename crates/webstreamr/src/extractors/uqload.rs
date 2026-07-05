use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_redirect_url, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static NOT_FOUND: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"File Not Found").unwrap());
static HEIGHT_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\d{3,}x(\d{3,})").unwrap());


pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let title = Html::parse_document(html)
        .select(&Selector::parse("h1").unwrap())
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .filter(|s| !s.is_empty());
    let height = HEIGHT_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());
    let url = build_redirect_url(mfp, "Uqload", page_url)?;

    Some(ExtractResult {
        url,
        format: StreamFormat::Mp4,
        title,
        height,
        yt_id: None,
        next_url: None,
        is_external: false,
        request_headers: None,
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}
