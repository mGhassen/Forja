use base64::Engine;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct XtreamCategory {
    pub category_id: String,
    pub category_name: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct XtreamChannel {
    pub num: Option<i32>,
    pub name: String,
    pub stream_id: Option<i64>,
    pub stream_icon: Option<String>,
    pub category_id: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum XtreamSection {
    Live,
    Vod,
    Series,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct XtreamStreamRow {
    pub stream_id: String,
    pub name: String,
    pub icon: String,
    pub category_id: String,
    pub container_ext: String,
    pub epg_channel_id: String,
    pub kind: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParsedCategory {
    pub id: String,
    pub name: String,
}

pub fn parse_categories(json: &str) -> Result<Vec<XtreamCategory>, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn parse_live_streams(json: &str) -> Result<Vec<XtreamChannel>, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn parse_categories_rows(json: &str) -> Result<Vec<ParsedCategory>, serde_json::Error> {
    let cats = parse_categories(json)?;
    Ok(cats
        .into_iter()
        .map(|c| ParsedCategory {
            id: c.category_id,
            name: c.category_name,
        })
        .collect())
}

pub fn parse_streams_rows(json: &str, section: XtreamSection) -> Result<Vec<XtreamStreamRow>, serde_json::Error> {
    let arr: Vec<Value> = serde_json::from_str(json)?;
    Ok(arr
        .iter()
        .filter_map(|value| parse_stream_row(value, section))
        .collect())
}

fn parse_stream_row(value: &Value, section: XtreamSection) -> Option<XtreamStreamRow> {
    let o = value.as_object()?;
    let container_ext = match section {
        XtreamSection::Live => "ts".to_string(),
        XtreamSection::Vod => {
            let ext = field_string(o, "container_extension");
            if ext.is_empty() {
                "mp4".to_string()
            } else {
                ext
            }
        }
        XtreamSection::Series => String::new(),
    };
    let stream_id = match section {
        XtreamSection::Series => {
            let series_id = field_string(o, "series_id");
            if series_id.is_empty() {
                field_string(o, "id")
            } else {
                series_id
            }
        }
        _ => {
            let stream_id = field_string(o, "stream_id");
            if stream_id.is_empty() {
                field_string(o, "id")
            } else {
                stream_id
            }
        }
    };
    let name = {
        let n = field_string(o, "name");
        if n.is_empty() {
            field_string(o, "title")
        } else {
            n
        }
    };
    let icon = {
        let i = field_string(o, "stream_icon");
        if i.is_empty() {
            field_string(o, "cover")
        } else {
            i
        }
    };
    Some(XtreamStreamRow {
        stream_id,
        name,
        icon,
        category_id: field_string(o, "category_id"),
        container_ext,
        epg_channel_id: field_string(o, "epg_channel_id"),
        kind: match section {
            XtreamSection::Live => "live",
            XtreamSection::Vod => "vod",
            XtreamSection::Series => "series",
        }
        .to_string(),
    })
}

fn field_string(o: &serde_json::Map<String, Value>, key: &str) -> String {
    o.get(key)
        .map(|v| match v {
            Value::String(s) => s.clone(),
            Value::Number(n) => n.to_string(),
            _ => v.to_string(),
        })
        .unwrap_or_default()
}

pub fn parse_section(section: &str) -> Option<XtreamSection> {
    match section {
        "live" => Some(XtreamSection::Live),
        "vod" => Some(XtreamSection::Vod),
        "series" => Some(XtreamSection::Series),
        _ => None,
    }
}

pub const UNCATEGORIZED_ID: &str = "__uncategorized__";

/// Portal groups missing from `get_*_categories` but still referenced by streams.
pub fn merge_orphan_categories(
    api: Vec<ParsedCategory>,
    streams: &[XtreamStreamRow],
) -> Vec<ParsedCategory> {
    let known: std::collections::HashSet<&str> = api
        .iter()
        .filter(|c| !c.id.is_empty() && c.id != UNCATEGORIZED_ID)
        .map(|c| c.id.as_str())
        .collect();
    let mut orphan_ids = std::collections::BTreeSet::new();
    let mut has_empty = false;
    for s in streams {
        if s.category_id.is_empty() {
            has_empty = true;
        } else if !known.contains(s.category_id.as_str()) {
            orphan_ids.insert(s.category_id.clone());
        }
    }
    if orphan_ids.is_empty() && !has_empty {
        return api;
    }
    let single_bucket = api.is_empty() && orphan_ids.len() == 1;
    let mut out = api;
    for id in orphan_ids {
        let name = if single_bucket {
            "Channels".to_string()
        } else {
            format!("Group {id}")
        };
        out.push(ParsedCategory { id, name });
    }
    if has_empty {
        out.push(ParsedCategory {
            id: UNCATEGORIZED_ID.to_string(),
            name: "Uncategorized".to_string(),
        });
    }
    out
}

pub fn parse_categories_json(json: &str) -> String {
    match parse_categories_rows(json) {
        Ok(rows) => serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into()),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

pub fn parse_streams_json(json: &str, section: &str) -> String {
    let Some(section) = parse_section(section) else {
        return json!({ "error": "invalid_section" }).to_string();
    };
    match parse_streams_rows(json, section) {
        Ok(rows) => serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into()),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ParsedSeriesEpisode {
    pub id: String,
    pub title: String,
    pub container_ext: String,
    pub season: i32,
    pub episode: i32,
    pub plot: String,
    pub image: String,
}

pub fn parse_series_episodes_rows(json: &str) -> Result<Vec<ParsedSeriesEpisode>, serde_json::Error> {
    let root: Value = serde_json::from_str(json)?;
    let Some(episodes_obj) = root.get("episodes").and_then(|v| v.as_object()) else {
        return Ok(vec![]);
    };

    let mut out = Vec::new();
    for (season_key, value) in episodes_obj {
        let season_num: i32 = season_key.parse().unwrap_or(0);
        let Some(arr) = value.as_array() else {
            continue;
        };
        for entry in arr {
            let Some(o) = entry.as_object() else {
                continue;
            };
            let info = o.get("info").and_then(|v| v.as_object());
            let ext = field_string(o, "container_extension");
            let episode_num = o
                .get("episode_num")
                .and_then(|v| {
                    v.as_i64()
                        .map(|n| n as i32)
                        .or_else(|| v.as_str().and_then(|s| s.parse().ok()))
                })
                .unwrap_or(0);
            out.push(ParsedSeriesEpisode {
                id: field_string(o, "id"),
                title: field_string(o, "title"),
                container_ext: if ext.is_empty() { "mp4".into() } else { ext },
                season: season_num,
                episode: episode_num,
                plot: info
                    .map(|i| field_string(i, "plot"))
                    .unwrap_or_default(),
                image: info
                    .map(|i| field_string(i, "movie_image"))
                    .unwrap_or_default(),
            });
        }
    }

    out.sort_by(|a, b| {
        a.season
            .cmp(&b.season)
            .then_with(|| a.episode.cmp(&b.episode))
    });
    Ok(out)
}

pub fn parse_series_episodes_json(json: &str) -> String {
    match parse_series_episodes_rows(json) {
        Ok(rows) => serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into()),
        Err(e) => json!({ "error": e.to_string() }).to_string(),
    }
}

/// Xtream encodes title/description as base64 strings in some responses.
pub fn decode_xtream_text(s: &str) -> String {
    if s.is_empty() {
        return String::new();
    }
    if let Ok(bytes) = base64::engine::general_purpose::STANDARD.decode(s) {
        if let Ok(text) = String::from_utf8(bytes) {
            return text.trim().to_string();
        }
    }
    s.trim().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_categories() {
        let json = r#"[{"category_id":"1","category_name":"Sports"}]"#;
        let cats = parse_categories_rows(json).unwrap();
        assert_eq!(cats[0].name, "Sports");
    }

    #[test]
    fn parses_live_streams() {
        let json = r#"[{"stream_id":42,"name":"News","stream_icon":"http://i","category_id":"1","epg_channel_id":"ch1"}]"#;
        let rows = parse_streams_rows(json, XtreamSection::Live).unwrap();
        assert_eq!(rows[0].stream_id, "42");
        assert_eq!(rows[0].container_ext, "ts");
        assert_eq!(rows[0].kind, "live");
    }

    #[test]
    fn parses_vod_streams() {
        let json = r#"[{"stream_id":"9","name":"Movie","container_extension":"mkv","category_id":"2"}]"#;
        let rows = parse_streams_rows(json, XtreamSection::Vod).unwrap();
        assert_eq!(rows[0].container_ext, "mkv");
        assert_eq!(rows[0].kind, "vod");
    }

    #[test]
    fn merges_orphan_live_categories() {
        let streams = vec![XtreamStreamRow {
            stream_id: "1".into(),
            name: "A".into(),
            icon: String::new(),
            category_id: "110".into(),
            container_ext: "ts".into(),
            epg_channel_id: String::new(),
            kind: "live".into(),
        }];
        let cats = merge_orphan_categories(vec![], &streams);
        assert_eq!(cats[0].id, "110");
        assert_eq!(cats[0].name, "Channels");
    }

    #[test]
    fn merges_uncategorized_bucket() {
        let streams = vec![
            XtreamStreamRow {
                stream_id: "1".into(),
                name: "A".into(),
                icon: String::new(),
                category_id: "110".into(),
                container_ext: "ts".into(),
                epg_channel_id: String::new(),
                kind: "live".into(),
            },
            XtreamStreamRow {
                stream_id: "2".into(),
                name: "B".into(),
                icon: String::new(),
                category_id: String::new(),
                container_ext: "ts".into(),
                epg_channel_id: String::new(),
                kind: "live".into(),
            },
        ];
        let cats = merge_orphan_categories(vec![], &streams);
        assert_eq!(cats.len(), 2);
        assert_eq!(cats[1].id, UNCATEGORIZED_ID);
    }
}
