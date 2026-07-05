use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum MediaType {
    Movie,
    Series,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum StreamFormat {
    Hls,
    Mp4,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StreamFile {
    pub url: String,
    pub quality: Option<String>,
    pub headers: Option<HashMap<String, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExtractResult {
    pub url: String,
    pub format: StreamFormat,
    pub title: Option<String>,
    pub height: Option<u32>,
    pub request_headers: Option<HashMap<String, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ResolveContext {
    pub imdb_id: Option<String>,
    pub tmdb_id: Option<i64>,
    pub media_type: MediaType,
    pub season: Option<i32>,
    pub episode: Option<i32>,
}
