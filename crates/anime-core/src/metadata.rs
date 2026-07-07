use serde::Deserialize;
use serde_json::json;

use crate::{introdb, lyrics};

#[derive(Debug, Deserialize)]
struct MetadataRequest {
    action: String,
    #[serde(default)]
    track_name: String,
    #[serde(default)]
    artist_name: String,
    #[serde(default)]
    album_name: String,
    #[serde(default)]
    duration_seconds: i64,
    #[serde(default)]
    tmdb_id: i64,
    #[serde(default)]
    season: Option<i32>,
    #[serde(default)]
    episode: Option<i32>,
    #[serde(default)]
    imdb_id: String,
}

pub fn metadata_request_json(request_json: &str) -> String {
    let req: MetadataRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "synced_lyrics" => match lyrics::synced_lyrics(
            &req.track_name,
            &req.artist_name,
            &req.album_name,
            req.duration_seconds,
        ) {
            Ok(lines) => serde_json::to_string(&json!({ "lines": lines }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "introdb_timestamps" => {
            let imdb = if req.imdb_id.is_empty() {
                None
            } else {
                Some(req.imdb_id.as_str())
            };
            match introdb::get_timestamps(req.tmdb_id, req.season, req.episode, imdb) {
                Ok(Some(data)) => serde_json::to_string(&json!({ "data": data }))
                    .unwrap_or_else(|_| "{}".into()),
                Ok(None) => json!({ "data": null }).to_string(),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}
