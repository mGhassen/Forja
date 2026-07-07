use regex::Regex;
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum M3uError {
    #[error("Playlist is empty")]
    Empty,
    #[error("No channels found — is this a valid M3U playlist?")]
    NoChannels,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct M3uChannel {
    pub name: String,
    pub url: String,
    pub logo: String,
    pub group: String,
    pub tvg_id: String,
    pub tvg_name: String,
}

static ATTR_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"([a-zA-Z0-9_\-]+)=("([^"]*)"|'([^']*)'|([^\s,]+))"#).unwrap()
});

fn looks_like_url(s: &str) -> bool {
    let lower = s.to_lowercase();
    [
        "http://",
        "https://",
        "rtmp://",
        "rtmps://",
        "rtsp://",
        "udp://",
        "rtp://",
        "mms://",
        "mmsh://",
    ]
    .iter()
    .any(|p| lower.starts_with(p))
}

fn parse_attrs(input: &str) -> std::collections::HashMap<String, String> {
    let mut result = std::collections::HashMap::new();
    let mut s = input.trim();
    if let Some(stripped) = s.strip_prefix(':') {
        s = stripped.trim();
    }
    if let Some(m) = Regex::new(r"^-?\d+(\.\d+)?").unwrap().find(s) {
        s = s[m.end()..].trim();
    }
    for caps in ATTR_RE.captures_iter(s) {
        let key = caps.get(1).unwrap().as_str().to_lowercase();
        let v = caps
            .get(3)
            .or_else(|| caps.get(4))
            .or_else(|| caps.get(5))
            .map(|m| m.as_str())
            .unwrap_or("");
        result.insert(key, v.to_string());
    }
    result
}

pub fn parse(content: &str) -> Result<Vec<M3uChannel>, M3uError> {
    if content.is_empty() {
        return Err(M3uError::Empty);
    }
    let text = content.replace("\r\n", "\n").replace('\r', "\n");
    let lines: Vec<&str> = text.split('\n').collect();
    let mut out = Vec::new();
    let mut pending_name: Option<String> = None;
    let mut pending_logo = String::new();
    let mut pending_group = String::new();
    let mut pending_tvg_id = String::new();
    let mut pending_tvg_name = String::new();

    for raw in lines {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with("#EXTM3U") {
            continue;
        }
        if let Some(rest) = line.strip_prefix("#EXTINF") {
            let comma_idx = rest.find(',');
            let (attr_part, name_part) = if let Some(idx) = comma_idx {
                (&rest[..idx], rest[idx + 1..].trim())
            } else {
                (rest, "")
            };
            let attrs = parse_attrs(attr_part);
            pending_tvg_id = attrs.get("tvg-id").cloned().unwrap_or_default();
            pending_tvg_name = attrs.get("tvg-name").cloned().unwrap_or_default();
            pending_logo = attrs.get("tvg-logo").cloned().unwrap_or_default();
            pending_group = attrs.get("group-title").cloned().unwrap_or_default();
            pending_name = Some(if !name_part.is_empty() {
                name_part.to_string()
            } else if !pending_tvg_name.is_empty() {
                pending_tvg_name.clone()
            } else {
                "Unknown".to_string()
            });
            continue;
        }
        if let Some(grp) = line.strip_prefix("#EXTGRP:") {
            pending_group = grp.trim().to_string();
            continue;
        }
        if line.starts_with('#') {
            continue;
        }
        let url = line;
        if !looks_like_url(url) {
            continue;
        }
        out.push(M3uChannel {
            name: pending_name.clone().unwrap_or_else(|| url.to_string()),
            url: url.to_string(),
            logo: pending_logo.clone(),
            group: pending_group.clone(),
            tvg_id: pending_tvg_id.clone(),
            tvg_name: pending_tvg_name.clone(),
        });
        pending_name = None;
        pending_logo.clear();
        pending_group.clear();
        pending_tvg_id.clear();
        pending_tvg_name.clear();
    }

    if out.is_empty() {
        return Err(M3uError::NoChannels);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic_playlist() {
        let content = r#"#EXTM3U
#EXTINF:-1 tvg-id="ch1" tvg-name="News" tvg-logo="http://logo" group-title="News",News HD
http://stream.example/live
"#;
        let channels = parse(content).unwrap();
        assert_eq!(channels.len(), 1);
        assert_eq!(channels[0].name, "News HD");
        assert_eq!(channels[0].group, "News");
    }
}
