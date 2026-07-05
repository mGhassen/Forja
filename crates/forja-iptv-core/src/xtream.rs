use base64::Engine;
use serde::{Deserialize, Serialize};

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

pub fn parse_categories(json: &str) -> Result<Vec<XtreamCategory>, serde_json::Error> {
    serde_json::from_str(json)
}

pub fn parse_live_streams(json: &str) -> Result<Vec<XtreamChannel>, serde_json::Error> {
    serde_json::from_str(json)
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
        let cats = parse_categories(json).unwrap();
        assert_eq!(cats[0].category_name, "Sports");
    }
}
