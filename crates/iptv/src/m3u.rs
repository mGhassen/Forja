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
    #[error("enigma2_bouquet")]
    Enigma2Bouquet,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct M3uChannel {
    pub name: String,
    pub url: String,
    pub logo: String,
    pub group: String,
    pub tvg_id: String,
    pub tvg_name: String,
    /// The provider's explicit `type="…"` attribute (e.g. `video` for VOD),
    /// when present. Some providers serve live and on-demand through
    /// identical playlists and only this attribute distinguishes them.
    #[serde(default)]
    pub entry_type: Option<String>,
}

/// The `#EXTM3U` header line plus every parsed entry.
#[derive(Debug, Clone, Default)]
pub struct ParseResult {
    pub channels: Vec<M3uChannel>,
    /// XMLTV guide URL from `url-tvg` / `x-tvg-url`, when the playlist
    /// carries one.
    pub epg_url: Option<String>,
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

fn nonempty(s: String) -> Option<String> {
    if s.is_empty() {
        None
    } else {
        Some(s)
    }
}

/// True when the playlist is actually an Enigma2 / Gigablue / Dreambox
/// `userbouquet` export — these use `#SERVICE` / `#NAME` / `#DESCRIPTION`
/// markers and never parse as an m3u. Providers hand one out when a
/// `get.php` URL carries `type=gigablue` (or `dreambox`).
fn looks_like_enigma2(content: &str) -> bool {
    for raw in content.split(['\n', '\r']) {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with("#EXTM3U") || line.starts_with("#EXTINF") {
            return false;
        }
        if line.starts_with("#SERVICE") || line.starts_with("#NAME") {
            return true;
        }
        // First meaningful line is something else entirely — not an m3u,
        // but not recognizably Enigma2 either; let the normal parser fail
        // with `NoChannels` instead of misreporting the format.
        return false;
    }
    false
}

/// Parses an m3u/m3u8 playlist, returning every entry plus the `#EXTM3U`
/// header's embedded EPG URL (`url-tvg` / `x-tvg-url`), when present.
pub fn parse_with_header(content: &str) -> Result<ParseResult, M3uError> {
    if content.is_empty() {
        return Err(M3uError::Empty);
    }
    if looks_like_enigma2(content) {
        return Err(M3uError::Enigma2Bouquet);
    }
    let text = content.replace("\r\n", "\n").replace('\r', "\n");
    let lines: Vec<&str> = text.split('\n').collect();
    let mut out = Vec::new();
    let mut epg_url: Option<String> = None;
    let mut pending_name: Option<String> = None;
    let mut pending_logo = String::new();
    let mut pending_group = String::new();
    let mut pending_tvg_id = String::new();
    let mut pending_tvg_name = String::new();
    let mut pending_type = String::new();

    for raw in lines {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with("#EXTM3U") {
            if epg_url.is_none() {
                let attrs = parse_attrs(line);
                epg_url = attrs
                    .get("url-tvg")
                    .or_else(|| attrs.get("x-tvg-url"))
                    .cloned()
                    .and_then(nonempty);
            }
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
            pending_type = attrs.get("type").cloned().unwrap_or_default();
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
            entry_type: nonempty(pending_type.clone()),
        });
        pending_name = None;
        pending_logo.clear();
        pending_group.clear();
        pending_tvg_id.clear();
        pending_tvg_name.clear();
        pending_type.clear();
    }

    if out.is_empty() {
        return Err(M3uError::NoChannels);
    }
    Ok(ParseResult {
        channels: out,
        epg_url,
    })
}

/// Parses an m3u/m3u8 playlist into its channel list. Thin wrapper over
/// [`parse_with_header`] for callers that don't need the EPG URL.
pub fn parse(content: &str) -> Result<Vec<M3uChannel>, M3uError> {
    parse_with_header(content).map(|r| r.channels)
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

    #[test]
    fn parses_header_epg_url_tvg() {
        let content = r#"#EXTM3U url-tvg="http://epg.example/guide.xml.gz"
#EXTINF:-1,Channel 1
http://stream.example/1
"#;
        let result = parse_with_header(content).unwrap();
        assert_eq!(
            result.epg_url.as_deref(),
            Some("http://epg.example/guide.xml.gz")
        );
        assert_eq!(result.channels.len(), 1);
    }

    #[test]
    fn parses_header_epg_x_tvg_url() {
        let content = r#"#EXTM3U x-tvg-url="http://epg.example/x.xml"
#EXTINF:-1,Channel 1
http://stream.example/1
"#;
        let result = parse_with_header(content).unwrap();
        assert_eq!(result.epg_url.as_deref(), Some("http://epg.example/x.xml"));
    }

    #[test]
    fn no_header_epg_url_is_none() {
        let content = r#"#EXTM3U
#EXTINF:-1,Channel 1
http://stream.example/1
"#;
        let result = parse_with_header(content).unwrap();
        assert_eq!(result.epg_url, None);
    }

    #[test]
    fn parses_type_attribute() {
        let content = r#"#EXTM3U
#EXTINF:-1 type="video" tvg-name="Movie",Some Movie
http://stream.example/movie
#EXTINF:-1,Channel 1
http://stream.example/live
"#;
        let channels = parse(content).unwrap();
        assert_eq!(channels[0].entry_type.as_deref(), Some("video"));
        assert_eq!(channels[1].entry_type, None);
    }

    #[test]
    fn rejects_empty_playlist() {
        let err = parse("").unwrap_err();
        assert!(err.to_string().contains("empty") || err.to_string().contains("Empty"));
    }

    #[test]
    fn detects_enigma2_bouquet() {
        let content = "#NAME Sports\n#SERVICE 1:0:1:0:0:0:0:0:0:0:http://x.example/1:Channel\n";
        let err = parse(content).unwrap_err();
        assert!(matches!(err, M3uError::Enigma2Bouquet));
    }

    #[test]
    fn does_not_misdetect_normal_playlist_as_enigma2() {
        let content = r#"#EXTM3U
#EXTINF:-1,Channel 1
http://stream.example/1
"#;
        assert!(parse(content).is_ok());
    }
}
