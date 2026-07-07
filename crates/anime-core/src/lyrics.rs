use regex::Regex;
use serde::Serialize;
use serde_json::Value;

use crate::http;

#[derive(Debug, Serialize)]
pub struct LyricLine {
    pub start_time_ms: i64,
    pub text: String,
}

pub fn synced_lyrics(
    track_name: &str,
    artist_name: &str,
    album_name: &str,
    duration_seconds: i64,
) -> Result<Vec<LyricLine>, String> {
    let url = format!(
        "https://lrclib.net/api/get?track_name={}&artist_name={}&album_name={}&duration={}",
        urlencoding::encode(track_name),
        urlencoding::encode(artist_name),
        urlencoding::encode(album_name),
        duration_seconds
    );
    let resp = http::fetch_with_retries("GET", &url, &Default::default(), None, None, false, 15, 0)?;
    if resp.status != 200 {
        return Err(format!("lrclib HTTP {}", resp.status));
    }
    let data: Value = serde_json::from_str(&resp.body).map_err(|e| e.to_string())?;
    let synced = data
        .get("syncedLyrics")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "no synced lyrics".to_string())?;
    Ok(parse_lrc(synced))
}

fn parse_lrc(content: &str) -> Vec<LyricLine> {
    static LINE_RE: std::sync::LazyLock<Regex> = std::sync::LazyLock::new(|| {
        Regex::new(r"\[(\d+):(\d+(?:\.\d+)?)\](.*)").expect("lrc line re")
    });
    let mut lines = Vec::new();
    for line in content.lines() {
        let Some(caps) = LINE_RE.captures(line.trim()) else {
            continue;
        };
        let Ok(minutes) = caps.get(1).unwrap().as_str().parse::<i64>() else {
            continue;
        };
        let Ok(seconds_f) = caps.get(2).unwrap().as_str().parse::<f64>() else {
            continue;
        };
        let text = caps.get(3).unwrap().as_str().trim();
        if text.is_empty() {
            continue;
        }
        let start_time_ms =
            minutes * 60_000 + (seconds_f * 1000.0).round() as i64;
        lines.push(LyricLine {
            start_time_ms,
            text: text.to_string(),
        });
    }
    lines
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_lrc_lines() {
        let lines = parse_lrc("[00:12.50]Hello world\n[01:02.00]Next");
        assert_eq!(lines.len(), 2);
        assert_eq!(lines[0].start_time_ms, 12_500);
        assert_eq!(lines[0].text, "Hello world");
    }
}
