use std::collections::HashMap;

use serde::Serialize;

use crate::http;

pub const DEFAULT_UA: &str =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
     (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

#[derive(Debug, Clone, Serialize)]
pub struct AnimeTrackOut {
    pub url: String,
    pub label: String,
    #[serde(default)]
    pub language: String,
    #[serde(default)]
    pub is_default: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct StreamResultOut {
    pub url: String,
    pub referer: String,
    pub origin: String,
    #[serde(default)]
    pub tracks: Vec<AnimeTrackOut>,
    #[serde(default)]
    pub provider: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub stream_label: Option<String>,
}

pub fn anime_get(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Result<http::AnimeHttpResponse, String> {
    http::fetch_with_retries("GET", url, headers, None, None, false, timeout_secs, 0)
}

pub fn anime_post(
    url: &str,
    headers: &HashMap<String, String>,
    body: &str,
    timeout_secs: u64,
) -> Result<http::AnimeHttpResponse, String> {
    http::fetch_with_retries("POST", url, headers, Some(body), None, false, timeout_secs, 0)
}

pub fn tokenize(s: &str, stopwords: &[&str]) -> std::collections::HashSet<String> {
    let lower = s.to_lowercase();
    let cleaned: String = lower
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { ' ' })
        .collect();
    cleaned
        .split_whitespace()
        .filter(|t| t.len() > 1 && !stopwords.contains(&t))
        .map(|t| t.to_string())
        .collect()
}

pub fn jaccard(a: &std::collections::HashSet<String>, b: &std::collections::HashSet<String>) -> f64 {
    if a.is_empty() || b.is_empty() {
        return 0.0;
    }
    let inter = a.intersection(b).count();
    if inter == 0 {
        return 0.0;
    }
    let union = a.len() + b.len() - inter;
    inter as f64 / union as f64
}

pub fn decode_html_entities(s: &str) -> String {
    s.replace("&amp;", "&")
        .replace("&#039;", "'")
        .replace("&apos;", "'")
        .replace("&quot;", "\"")
        .replace("&#8217;", "\u{2019}")
        .replace("&#8220;", "\u{201C}")
        .replace("&#8221;", "\u{201D}")
        .replace("&#8211;", "\u{2013}")
        .replace("&#8212;", "\u{2014}")
        .replace("&#8230;", "\u{2026}")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
}
