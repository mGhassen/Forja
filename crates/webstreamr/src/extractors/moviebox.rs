use crate::fetcher::{fetch_json, FetchConfig};
use crate::types::{ExtractResult, StreamFormat};
use serde::Deserialize;
use std::collections::HashMap;
use url::Url;

const REFERER: &str = "https://videodownloader.site/";

#[derive(Debug, Deserialize)]
struct DownloadResponse {
    code: i64,
    data: Option<DownloadData>,
}

#[derive(Debug, Deserialize)]
struct DownloadData {
    downloads: Vec<DownloadItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DownloadItem {
    format: Option<String>,
    url: String,
    resolution: Option<u32>,
    size: Option<String>,
}

pub fn supports_host(host: &str) -> bool {
    host.contains("moviebox") || host.contains("aoneroom")
}

/// MovieBox download API URL → playable streams.
pub fn extract_from_download_url(page_url: &str) -> Vec<ExtractResult> {
    let Ok(parsed) = Url::parse(page_url) else {
        return Vec::new();
    };
    if parsed.query_pairs().find(|(k, _)| k == "subjectId").is_none() {
        return Vec::new();
    }

    let mut headers = HashMap::from([
        ("Accept".into(), "application/json".into()),
        ("X-Client-Info".into(), r#"{"timezone":"UTC"}"#.into()),
        ("Referer".into(), REFERER.into()),
        (
            "User-Agent".into(),
            crate::fetcher::DEFAULT_USER_AGENT.into(),
        ),
    ]);
    let cfg = FetchConfig {
        headers: std::mem::take(&mut headers),
        ..FetchConfig::default()
    };
    let Ok(value) = fetch_json(page_url, &cfg) else {
        return Vec::new();
    };
    let Ok(resp) = serde_json::from_value::<DownloadResponse>(value) else {
        return Vec::new();
    };
    if resp.code != 0 {
        return Vec::new();
    }
    let Some(data) = resp.data else {
        return Vec::new();
    };

    let mut out = Vec::new();
    for dl in data.downloads {
        let is_hls = dl.url.contains(".m3u8");
        let format_upper = dl.format.as_deref().unwrap_or("").to_uppercase();
        let is_mp4 = dl.url.contains(".mp4") || format_upper == "MP4";
        let format = if is_hls {
            StreamFormat::Hls
        } else if is_mp4 {
            StreamFormat::Mp4
        } else {
            StreamFormat::Unknown
        };
        let height = dl.resolution.filter(|h| *h > 0);
        let bytes = dl
            .size
            .as_deref()
            .and_then(|s| s.parse::<u64>().ok())
            .filter(|b| *b > 0);
        let label = height
            .map(|h| format!("{h}p"))
            .unwrap_or_else(|| "MovieBox".into());
        out.push(ExtractResult {
            url: dl.url,
            format,
            title: None,
            height,
            yt_id: None,
            next_url: None,
            is_external: false,
            request_headers: Some(HashMap::from([("Referer".into(), REFERER.into())])),
            label: Some(label),
            bytes,
            meta_extractor_id: Some("moviebox".into()),
        });
    }
    out
}
