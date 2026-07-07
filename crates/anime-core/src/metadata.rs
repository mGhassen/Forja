use serde::Deserialize;
use serde_json::json;

use crate::{introdb, lyrics, mdblist};

#[derive(Debug, Deserialize)]
struct MetadataRequest {
    action: String,
    #[serde(default)]
    api_key: String,
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
    #[serde(default)]
    list_id: i64,
    #[serde(default)]
    media_type: String,
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
        "mdblist_user_info" => match mdblist::user_info(&req.api_key) {
            Ok(data) => serde_json::to_string(&json!({ "data": data }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "mdblist_ratings_by_imdb" => match mdblist::ratings_by_imdb(&req.api_key, &req.imdb_id) {
            Ok(data) => serde_json::to_string(&json!({ "data": data }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "mdblist_ratings_by_tmdb" => {
            let inner = mdblist::RatingsByTmdb {
                api_key: req.api_key,
                tmdb_id: req.tmdb_id,
                media_type: req.media_type,
            };
            match mdblist::ratings_by_tmdb(&inner) {
                Ok(data) => serde_json::to_string(&json!({ "data": data }))
                    .unwrap_or_else(|_| "{}".into()),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "mdblist_user_lists" => match mdblist::user_lists(&req.api_key) {
            Ok(items) => serde_json::to_string(&json!({ "items": items }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "mdblist_list_items" => {
            let inner = mdblist::ListIdRequest {
                api_key: req.api_key,
                list_id: req.list_id,
            };
            match mdblist::list_items(&inner) {
                Ok(items) => serde_json::to_string(&json!({ "items": items }))
                    .unwrap_or_else(|_| "{}".into()),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        "mdblist_top_lists" => match mdblist::top_lists(&req.api_key) {
            Ok(items) => serde_json::to_string(&json!({ "items": items }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "mdblist_remove_from_list" => {
            let inner = mdblist::RemoveFromListRequest {
                api_key: req.api_key,
                list_id: req.list_id,
                imdb_id: req.imdb_id,
                tmdb_id: if req.tmdb_id == 0 {
                    None
                } else {
                    Some(req.tmdb_id)
                },
                media_type: req.media_type,
            };
            match mdblist::remove_from_list(&inner) {
                Ok(ok) => json!({ "ok": ok }).to_string(),
                Err(e) => json!({ "error": e }).to_string(),
            }
        }
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}
