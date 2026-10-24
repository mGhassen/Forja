use serde::Serialize;
use serde_json::Value;

use crate::fetch;

const PRIMARY_BASE: &str = "https://api.theintrodb.org/v4";
const FALLBACK_BASE: &str = "https://api.introdb.app";

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct IntroDbTimestamp {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_ms: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_ms: Option<i64>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
pub struct IntroDbResponse {
    pub tmdb_id: i64,
    pub kind: String,
    pub intro: Vec<IntroDbTimestamp>,
    pub recap: Vec<IntroDbTimestamp>,
    pub credits: Vec<IntroDbTimestamp>,
    pub preview: Vec<IntroDbTimestamp>,
}

pub fn get_timestamps(
    tmdb_id: i64,
    season: Option<i32>,
    episode: Option<i32>,
    imdb_id: Option<&str>,
) -> Result<Option<IntroDbResponse>, String> {
    let primary = fetch_primary(tmdb_id, season, episode)?;
    let fallback = match imdb_id.filter(|s| !s.is_empty()) {
        Some(id) => fetch_fallback(id, season, episode)?,
        None => None,
    };
    Ok(merge(primary, fallback))
}

fn merge(
    primary: Option<IntroDbResponse>,
    fallback: Option<IntroDbResponse>,
) -> Option<IntroDbResponse> {
    match (primary, fallback) {
        (None, None) => None,
        (None, fb) => fb,
        (Some(p), None) => Some(p),
        (Some(p), Some(f)) => Some(IntroDbResponse {
            tmdb_id: p.tmdb_id,
            kind: p.kind,
            intro: pick_segments(&p.intro, &f.intro),
            recap: pick_segments(&p.recap, &f.recap),
            credits: pick_segments(&p.credits, &f.credits),
            preview: pick_segments(&p.preview, &f.preview),
        }),
    }
}

fn pick_segments(primary: &[IntroDbTimestamp], fallback: &[IntroDbTimestamp]) -> Vec<IntroDbTimestamp> {
    if !primary.is_empty() {
        primary.to_vec()
    } else {
        fallback.to_vec()
    }
}

fn fetch_primary(
    tmdb_id: i64,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Option<IntroDbResponse>, String> {
    let url = primary_url(tmdb_id, season, episode);
    let (status, body) = fetch::get(&url, &Default::default(), 8)?;
    if status != 200 {
        return Ok(None);
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    if !data.is_object() {
        return Ok(None);
    }
    Ok(Some(parse_primary(&data, tmdb_id)))
}

fn primary_url(tmdb_id: i64, season: Option<i32>, episode: Option<i32>) -> String {
    let mut url = format!("{PRIMARY_BASE}/media?tmdb_id={tmdb_id}");
    if let Some(s) = season {
        url.push_str(&format!("&season={s}"));
    }
    if let Some(e) = episode {
        url.push_str(&format!("&episode={e}"));
    }
    url
}

fn fetch_fallback(
    imdb_id: &str,
    season: Option<i32>,
    episode: Option<i32>,
) -> Result<Option<IntroDbResponse>, String> {
    let mut url = format!("{FALLBACK_BASE}/segments?imdb_id={}", urlencoding::encode(imdb_id));
    if let Some(s) = season {
        url.push_str(&format!("&season={s}"));
    }
    if let Some(e) = episode {
        url.push_str(&format!("&episode={e}"));
    }
    let (status, body) = fetch::get(&url, &Default::default(), 8)?;
    if status != 200 {
        return Ok(None);
    }
    let data: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
    if !data.is_object() {
        return Ok(None);
    }
    Ok(Some(parse_fallback(&data)))
}

// v4 bodies are keyed by tvdb_id and carry no tmdb_id, so echo the id we asked with.
fn parse_primary(json: &Value, tmdb_id: i64) -> IntroDbResponse {
    IntroDbResponse {
        tmdb_id,
        kind: json
            .get("type")
            .and_then(|v| v.as_str())
            .unwrap_or("primary")
            .to_string(),
        intro: parse_segment_list(json.get("intro")),
        recap: parse_segment_list(json.get("recap")),
        credits: parse_segment_list(json.get("credits")),
        preview: parse_segment_list(json.get("preview")),
    }
}

fn parse_fallback(json: &Value) -> IntroDbResponse {
    let intro = parse_single_segment(json.get("intro"));
    let recap = parse_single_segment(json.get("recap"));
    let credits = parse_single_segment(json.get("outro"));
    IntroDbResponse {
        tmdb_id: 0,
        kind: "fallback".into(),
        intro: intro.into_iter().collect(),
        recap: recap.into_iter().collect(),
        credits: credits.into_iter().collect(),
        preview: vec![],
    }
}

fn parse_segment_list(value: Option<&Value>) -> Vec<IntroDbTimestamp> {
    let Some(value) = value else {
        return vec![];
    };
    if let Some(arr) = value.as_array() {
        return arr.iter().filter_map(parse_timestamp).collect();
    }
    parse_timestamp(value).into_iter().collect()
}

fn parse_single_segment(value: Option<&Value>) -> Option<IntroDbTimestamp> {
    value.and_then(parse_timestamp)
}

fn parse_timestamp(value: &Value) -> Option<IntroDbTimestamp> {
    let obj = value.as_object()?;
    let mut start_ms = obj.get("start_ms").and_then(|v| v.as_i64());
    let mut end_ms = obj.get("end_ms").and_then(|v| v.as_i64());
    if start_ms.is_none() {
        start_ms = obj
            .get("start_sec")
            .and_then(|v| v.as_f64())
            .map(|s| (s * 1000.0).round() as i64);
    }
    if end_ms.is_none() {
        end_ms = obj
            .get("end_sec")
            .and_then(|v| v.as_f64())
            .map(|s| (s * 1000.0).round() as i64);
    }
    if start_ms.is_none() && end_ms.is_none() {
        return None;
    }
    Some(IntroDbTimestamp { start_ms, end_ms })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn primary_url_targets_v4() {
        assert_eq!(
            primary_url(456, Some(1), Some(2)),
            "https://api.theintrodb.org/v4/media?tmdb_id=456&season=1&episode=2"
        );
    }

    #[test]
    fn parses_v4_body_without_tmdb_id() {
        let body: Value = serde_json::from_str(
            r#"{"tvdb_id":71663,"type":"tv","season":1,"episode":1,
                "intro":[{"start_ms":null,"end_ms":23000}]}"#,
        )
        .unwrap();
        let r = parse_primary(&body, 456);
        assert_eq!(r.tmdb_id, 456);
        assert_eq!(r.kind, "tv");
        assert_eq!(r.intro, vec![IntroDbTimestamp { start_ms: None, end_ms: Some(23_000) }]);
    }

    #[test]
    fn merges_segment_types() {
        let primary = IntroDbResponse {
            tmdb_id: 1,
            kind: "tv".into(),
            intro: vec![IntroDbTimestamp {
                start_ms: Some(0),
                end_ms: Some(90_000),
            }],
            recap: vec![],
            credits: vec![],
            preview: vec![],
        };
        let fallback = IntroDbResponse {
            tmdb_id: 0,
            kind: "fallback".into(),
            intro: vec![],
            recap: vec![IntroDbTimestamp {
                start_ms: Some(1000),
                end_ms: Some(2000),
            }],
            credits: vec![],
            preview: vec![],
        };
        let merged = merge(Some(primary), Some(fallback)).unwrap();
        assert_eq!(merged.intro.len(), 1);
        assert_eq!(merged.recap.len(), 1);
    }
}
