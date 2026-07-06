use crate::types::{ExtractResult, StreamFormat};
use crate::utils::{build_stream_url, parse_bytes, MfpConfig};
use regex::Regex;
use std::sync::LazyLock;

static NOT_FOUND: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"No such file").unwrap());
static META_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\d{3,}x(\d{3,}), ([\d.]+ ?[GM]B)").unwrap());
static TITLE_RE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r">Download (.*?)<").unwrap());

pub fn extract_from_html(
    html: &str,
    page_url: &str,
    mfp: &MfpConfig,
    download_html: &str,
) -> Option<ExtractResult> {
    if NOT_FOUND.is_match(download_html) {
        return None;
    }
    let title = TITLE_RE
        .captures(download_html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().trim().to_string())
        .filter(|s| !s.is_empty());
    let (height, bytes) = META_RE
        .captures(download_html)
        .map(|c| {
            let height = c.get(1).and_then(|m| m.as_str().parse().ok());
            let bytes = c
                .get(2)
                .map(|m| m.as_str())
                .and_then(parse_bytes);
            (height, bytes)
        })
        .unwrap_or((None, None));
    let _ = html;
    let url = build_stream_url(mfp, "Fastream", page_url)?;

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
