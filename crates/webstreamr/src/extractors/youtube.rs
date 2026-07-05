use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::sync::LazyLock;
use url::Url;

static TITLE_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#""title":\{"runs":\[\{"text":"(.*?)""#).unwrap()
});

pub fn supports_host(host: &str) -> bool {
    host.contains("youtube")
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    let page = Url::parse(page_url).ok()?;
    if !page.query_pairs().any(|(k, _)| k == "v") {
        return None;
    }
    let yt_id = page
        .query_pairs()
        .find(|(k, _)| k == "v")
        .map(|(_, v)| v.into_owned())?;
    let title = TITLE_RE
        .captures(html)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str().to_string());

    Some(ExtractResult {
        url: page_url.to_string(),
        format: StreamFormat::Unknown,
        title,
        yt_id: Some(yt_id),
        ..Default::default()
    })
}
