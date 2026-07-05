use crate::types::{ExtractResult, StreamFormat};
use url::Url;

pub fn supports_host(_host: &str) -> bool {
    true
}

pub fn extract_from_html(_html: &str, page_url: &str) -> Option<ExtractResult> {
    let page = Url::parse(page_url).ok()?;
    Some(ExtractResult {
        url: page.to_string(),
        format: StreamFormat::Unknown,
        title: None,
        height: None,
        yt_id: None,
        next_url: None,
        is_external: true,
        request_headers: None,
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}
