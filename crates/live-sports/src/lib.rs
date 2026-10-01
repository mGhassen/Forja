mod espn;
mod fetch;
mod sport_epg_cache;
mod sport_match;
mod stalker_sport;
mod xtream_sport;

use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Clone, Deserialize)]
pub struct LiveMatchesRequest {
    pub action: String,
    /// Game object for `sport_match_streams`.
    #[serde(default)]
    pub game: Option<Value>,
    /// Xtream portal `{ url, username, password }`.
    #[serde(default)]
    pub xtream: Option<Value>,
    /// Stalker portal `{ url, username (MAC), password (serial) }`.
    #[serde(default)]
    pub stalker: Option<Value>,
    /// Live category ids to search (plus caller may include GLOBAL).
    #[serde(default)]
    pub category_ids: Option<Vec<String>>,
    /// When true, match on channel names only — skip short-EPG fetches (fast first batch).
    #[serde(default)]
    pub skip_epg: Option<bool>,
    /// Start index into the EPG shortlist for batched progressive resolve.
    #[serde(default)]
    pub epg_offset: Option<u32>,
    /// Max short-EPG fetches this call (`0` = all remaining when batching is off).
    #[serde(default)]
    pub epg_limit: Option<u32>,
    /// Stream ids already shown to the host — omit from `items`.
    #[serde(default)]
    pub exclude_stream_ids: Option<Vec<String>>,
}

pub fn fetch_json(request_json: &str) -> String {
    let req: LiveMatchesRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => {
            return serde_json::json!({ "error": format!("invalid request: {e}") }).to_string();
        }
    };

    match req.action.as_str() {
        "sport_match_streams" => {
            let game = match req.game {
                Some(g) => g,
                None => {
                    return serde_json::json!({ "error": "game required" }).to_string();
                }
            };
            let cats = req.category_ids.unwrap_or_default();
            let opts = sport_match::SportStreamsOpts {
                skip_epg: req.skip_epg.unwrap_or(false),
                epg_offset: req.epg_offset.map(|n| n as usize),
                epg_limit: req.epg_limit.map(|n| n as usize),
                exclude_stream_ids: req.exclude_stream_ids.unwrap_or_default(),
            };
            match (req.xtream, req.stalker) {
                (Some(x), None) => xtream_sport::sport_match_streams(&game, &x, &cats, opts),
                (None, Some(s)) => stalker_sport::sport_match_streams(&game, &s, &cats, opts),
                (Some(_), Some(_)) => {
                    serde_json::json!({ "error": "provide xtream or stalker, not both" })
                        .to_string()
                }
                (None, None) => {
                    serde_json::json!({ "error": "xtream or stalker required" }).to_string()
                }
            }
        }
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
    fn sport_match_streams_requires_game() {
        let raw = fetch_json(r#"{"action":"sport_match_streams","xtream":{"url":"http://x"}}"#);
        assert!(raw.contains("game required"));
    }

    #[test]
    fn sport_match_streams_requires_portal() {
        let raw = fetch_json(r#"{"action":"sport_match_streams","game":{"title":"x"}}"#);
        assert!(raw.contains("xtream or stalker required"));
    }
}
