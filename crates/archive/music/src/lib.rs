mod deezer;
mod http;
mod types;
mod youtube;

use serde::Deserialize;
use serde_json::json;

pub use types::{MusicAlbum, MusicTrack};

#[derive(Debug, Deserialize)]
struct MusicRequest {
    action: String,
    #[serde(default)]
    q: String,
    #[serde(default)]
    index: u32,
    #[serde(default = "default_limit")]
    limit: u32,
    #[serde(default)]
    album_id: String,
    #[serde(default)]
    track_id: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    artist: String,
    #[serde(default)]
    video_id: String,
}

fn default_limit() -> u32 {
    20
}

pub fn request_json(request_json: &str) -> String {
    let req: MusicRequest = match serde_json::from_str(request_json) {
        Ok(v) => v,
        Err(e) => return json!({ "error": format!("invalid request: {e}") }).to_string(),
    };

    match req.action.as_str() {
        "search_tracks" => match deezer::search_tracks(&req.q) {
            Ok(tracks) => serde_json::to_string(&json!({ "tracks": tracks }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "trending_tracks" => match deezer::trending_tracks(req.index, req.limit) {
            Ok(tracks) => serde_json::to_string(&json!({ "tracks": tracks }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "search_albums" => match deezer::search_albums(&req.q) {
            Ok(albums) => serde_json::to_string(&json!({ "albums": albums }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "album_tracks" => match deezer::album_tracks(&req.album_id) {
            Ok(tracks) => serde_json::to_string(&json!({ "tracks": tracks }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "related_tracks" => match deezer::related_tracks(&req.track_id) {
            Ok(tracks) => serde_json::to_string(&json!({ "tracks": tracks }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "youtube_search_video_id" => match youtube::search_video_id(&req.title, &req.artist) {
            Ok(Some(id)) => serde_json::to_string(&json!({ "video_id": id }))
                .unwrap_or_else(|_| "{}".into()),
            Ok(None) => json!({ "video_id": null }).to_string(),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "youtube_audio_url" => match youtube::audio_url(&req.video_id) {
            Ok(url) => serde_json::to_string(&json!({ "url": url }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "youtube_audio_streams" => match youtube::audio_streams(&req.video_id) {
            Ok(streams) => serde_json::to_string(&json!({ "streams": streams }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_unknown_action() {
        let raw = request_json(r#"{"action":"nope"}"#);
        assert!(raw.contains("unknown action"));
    }
}
