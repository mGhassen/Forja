use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StremioManifest {
    pub id: Option<String>,
    pub name: Option<String>,
    pub description: Option<String>,
    pub version: Option<String>,
    pub logo: Option<String>,
    pub resources: Option<Vec<String>>,
    pub types: Option<Vec<String>>,
    pub catalogs: Option<Vec<serde_json::Value>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StremioStreamResponse {
    pub streams: Option<Vec<serde_json::Value>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StremioSubtitleResponse {
    pub subtitles: Option<Vec<serde_json::Value>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParsedAddonUrl {
    pub base_url: String,
    pub query_params: Option<String>,
}

pub fn parse_manifest(json: &str) -> Result<StremioManifest, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn parse_streams(json: &str) -> Result<StremioStreamResponse, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn parse_subtitles(json: &str) -> Result<StremioSubtitleResponse, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn split_addon_url(url: &str) -> ParsedAddonUrl {
    let trimmed = url.trim();
    let (path, query) = if let Some(idx) = trimmed.find('?') {
        (&trimmed[..idx], Some(trimmed[idx + 1..].to_string()))
    } else {
        (trimmed, None)
    };
    let mut base = path
        .trim_end_matches("/manifest.json")
        .trim_end_matches('/')
        .to_string();
    if !base.starts_with("http") {
        base = format!("https://{base}");
    }
    ParsedAddonUrl {
        base_url: base,
        query_params: query,
    }
}

pub fn build_resource_url(addon_url: &str, resource_path: &str) -> String {
    let parts = split_addon_url(addon_url);
    if let Some(qp) = parts.query_params {
        format!("{}{}?{}", parts.base_url, resource_path, qp)
    } else {
        format!("{}{}", parts.base_url, resource_path)
    }
}

pub fn normalize_manifest_url(url: &str) -> String {
    let mut manifest_url = url.trim().to_string();
    if manifest_url.starts_with("stremio://") {
        manifest_url = manifest_url.replacen("stremio://", "https://", 1);
    }
    if !manifest_url.ends_with("/manifest.json") {
        manifest_url = if manifest_url.ends_with('/') {
            format!("{manifest_url}manifest.json")
        } else {
            format!("{manifest_url}/manifest.json")
        };
    }
    manifest_url
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_query_params() {
        let p = split_addon_url("https://addon.example/api?token=abc");
        assert_eq!(p.base_url, "https://addon.example/api");
        assert_eq!(p.query_params.as_deref(), Some("token=abc"));
    }

    #[test]
    fn builds_stream_url() {
        let url = build_resource_url(
            "https://addon.example/api?token=abc",
            "/stream/movie/tt123.json",
        );
        assert_eq!(
            url,
            "https://addon.example/api/stream/movie/tt123.json?token=abc"
        );
    }

    #[test]
    fn parses_manifest_json() {
        let m = parse_manifest(r#"{"name":"Addon","logo":"https://x/icon.png"}"#).unwrap();
        assert_eq!(m.name.as_deref(), Some("Addon"));
    }

    #[test]
    fn parses_streams_json() {
        let s = parse_streams(r#"{"streams":[{"url":"https://cdn.example/a.m3u8"}]}"#).unwrap();
        assert_eq!(s.streams.as_ref().map(|v| v.len()), Some(1));
    }
}
