use crate::types::{ExtractResult, StreamFormat};
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
struct RgShowsPayload {
    stream: RgShowsStream,
}

#[derive(Debug, Deserialize)]
struct RgShowsStream {
    url: String,
}

pub fn supports_host(host: &str) -> bool {
    host.contains("rgshows")
}

pub fn extract_from_html(json_body: &str, _page_url: &str) -> Option<ExtractResult> {
    let payload: RgShowsPayload = serde_json::from_str(json_body).ok()?;
    if payload.stream.url.contains("vidzee") {
        return None;
    }
    let url = payload.stream.url;
    let format = if url.contains("mp4") {
        StreamFormat::Mp4
    } else if url.contains("m3u8") || url.contains("txt") {
        StreamFormat::Hls
    } else {
        StreamFormat::Unknown
    };

    let mut request_headers = HashMap::new();
    request_headers.insert("Referer".into(), "https://www.rgshows.ru/".into());
    request_headers.insert("Origin".into(), "https://www.rgshows.ru".into());
    request_headers.insert("User-Agent".into(), "Mozilla".into());

    Some(ExtractResult {
        url,
        format,
        title: None,
        height: None,
        yt_id: None,
        next_url: None,
        is_external: false,
        request_headers: Some(request_headers),
        label: None,
        bytes: None,
        meta_extractor_id: None,
    })
}
