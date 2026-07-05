use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_stream_url, parse_bytes, MfpConfig};
use regex::Regex;
use scraper::{Html, Selector};
use std::sync::LazyLock;

static NOT_FOUND: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"File Not Found|deleted by administration").unwrap());
static HEIGHT_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(\d{3,})p").unwrap());
static SIZE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([\d.]+ ?[GM]B)").unwrap());

pub fn extract_redirect_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    if !html.contains("This video can be watched as embed only") {
        return None;
    }
    Some(ExtractResult {
        url: String::new(),
        format: StreamFormat::Unknown,
        title: None,
        height: None,
        yt_id: None,
        next_url: Some(page_url.replace("/f/", "/v/")),
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
    if html.contains("This video can be watched as embed only") {
        return None;
    }
    if NOT_FOUND.is_match(html) {
        return None;
    }
    let unpacked = utils::js_unpacker::unpack_eval(html).ok()?;
    let height = HEIGHT_RE
        .captures(&unpacked)
        .and_then(|c| c.get(1))
        .and_then(|m| m.as_str().parse().ok());
    let bytes = SIZE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
        .and_then(|s| parse_bytes(s));
    let title = Html::parse_document(html)
        .select(&Selector::parse(r#"meta[name="description"]"#).unwrap())
        .next()
        .and_then(|el| el.value().attr("content"))
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    let url = build_stream_url(mfp, "FileLions", page_url)?;

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
