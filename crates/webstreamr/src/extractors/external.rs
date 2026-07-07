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
        is_external: true,
        ..Default::default()
    })
}
