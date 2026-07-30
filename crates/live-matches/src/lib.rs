mod fetch;

use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct LiveMatchesRequest {
    pub action: String,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub id: Option<String>,
}

pub fn fetch_json(request_json: &str) -> String {
    let req: LiveMatchesRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    match req.action.as_str() {
        "streamed_sports" => fetch::streamed_sports(),
        "streamed_matches" => fetch::streamed_matches(),
        "streamed_streams" => {
            let source = req.source.unwrap_or_default();
            let id = req.id.unwrap_or_default();
            if source.is_empty() || id.is_empty() {
                return serde_json::json!({ "error": "source and id required" }).to_string();
            }
            fetch::streamed_streams(&source, &id)
        }
        "damitv_streams" => fetch::damitv_streams(),
        "cdn_channels" => fetch::cdn_channels(),
        "cdn_sports" => fetch::cdn_sports(),
        "mut_matches" => fetch::mut_matches(),
        other => serde_json::json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = fetch_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }

    #[test]
    fn streamed_streams_requires_params() {
        let raw = fetch_json(r#"{"action":"streamed_streams"}"#);
        assert!(raw.contains("source and id required"));
    }
}
