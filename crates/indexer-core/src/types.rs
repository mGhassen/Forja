use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TorrentRow {
    pub name: String,
    pub magnet: String,
    pub seeders: String,
    pub size: String,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConnectionTest {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub indexer_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProwlarrTag {
    pub id: i64,
    pub label: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ResolvedLink {
    pub is_magnet: bool,
    pub link: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub torrent_base64: Option<String>,
}

pub fn format_size(bytes: i64) -> String {
    if bytes <= 0 {
        return "Unknown".into();
    }
    let gb = 1024_i64 * 1024 * 1024;
    let mb = 1024_i64 * 1024;
    if bytes < gb {
        return format!("{:.1} MB", bytes as f64 / mb as f64);
    }
    format!("{:.2} GB", bytes as f64 / gb as f64)
}

pub fn normalize_base_url(url: &str) -> String {
    url.trim().trim_end_matches('/').to_string()
}
