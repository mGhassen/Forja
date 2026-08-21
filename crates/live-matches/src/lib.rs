mod espn;
mod fetch;
mod sport_match;
mod xtream_sport;

use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Clone, Deserialize)]
pub struct LiveMatchesRequest {
    pub action: String,
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub id: Option<String>,
    /// ESPN leagues for `sport_match_games` (e.g. NBA, NFL).
    #[serde(default)]
    pub leagues: Option<Vec<String>>,
    /// Local calendar day YYYYMMDD for ESPN `dates=` filter.
    #[serde(default)]
    pub date: Option<String>,
    /// Game object for `sport_match_streams`.
    #[serde(default)]
    pub game: Option<Value>,
    /// Xtream portal `{ url, username, password }`.
    #[serde(default)]
    pub xtream: Option<Value>,
    /// Live category ids to search (plus caller may include GLOBAL).
    #[serde(default)]
    pub category_ids: Option<Vec<String>>,
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
        "mut_matches" => fetch::mut_matches(),
        "sport_match_games" => {
            let leagues = req.leagues.unwrap_or_default();
            espn::sport_match_games(&leagues, req.date.as_deref())
        }
        "sport_match_streams" => {
            let game = match req.game {
                Some(g) => g,
                None => {
                    return serde_json::json!({ "error": "game required" }).to_string();
                }
            };
            let xtream = match req.xtream {
                Some(x) => x,
                None => {
                    return serde_json::json!({ "error": "xtream required" }).to_string();
                }
            };
            let cats = req.category_ids.unwrap_or_default();
            xtream_sport::sport_match_streams(&game, &xtream, &cats)
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
    fn streamed_streams_requires_params() {
        let raw = fetch_json(r#"{"action":"streamed_streams"}"#);
        assert!(raw.contains("source and id required"));
    }

    #[test]
    fn sport_match_streams_requires_game() {
        let raw = fetch_json(r#"{"action":"sport_match_streams","xtream":{"url":"http://x"}}"#);
        assert!(raw.contains("game required"));
    }
}
