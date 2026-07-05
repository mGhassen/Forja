use crate::types::{ExtractResult, StreamFormat};
use regex::Regex;
use std::sync::LazyLock;
use url::Url;

static NOT_READY: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"Video is not ready").unwrap());
static VIDEO_RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"video ?= ?(.*);").unwrap());

pub fn supports_host(host: &str) -> bool {
    Regex::new(r"bullstream|mp4player|watch\.gxplayer")
        .unwrap()
        .is_match(host)
}

pub fn extract_from_html(html: &str, page_url: &str) -> Option<ExtractResult> {
    if NOT_READY.is_match(html) {
        return None;
    }
    let video_json = VIDEO_RE.captures(html)?.get(1)?.as_str();
    let video: serde_json::Value = serde_json::from_str(video_json).ok()?;
    let page = Url::parse(page_url).ok()?;
    let host = page.host_str()?;
    let origin = format!("{}://{}", page.scheme(), host);
    let uid = video.get("uid")?.as_str()?;
    let md5 = video.get("md5")?.as_str()?;
    let id = video.get("id")?;
    let id_str = match id {
        serde_json::Value::Number(n) => n.to_string(),
        serde_json::Value::String(s) => s.clone(),
        _ => return None,
    };
    let status = video.get("status")?.as_str()?;
    let m3u8 = format!(
        "{origin}/m3u8/{uid}/{md5}/master.txt?s=1&id={id_str}&cache={status}"
    );
    let quality_raw = video.get("quality")?.as_str()?;
    let quality_list: Vec<String> = serde_json::from_str(quality_raw).ok()?;
    let height = quality_list.first().and_then(|s| s.parse().ok());
    let title = video.get("title")?.as_str().map(|t| t.to_string());

    Some(ExtractResult {
        url: m3u8,
        format: StreamFormat::Hls,
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
