use serde::Deserialize;
use serde_json::json;

use crate::{lyrics, paper2audio};

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
    file_name: String,
    #[serde(default)]
    voice_id: String,
    #[serde(default)]
    run_id: String,
    #[serde(default)]
    epub_base64: String,
}

pub fn media_extra_request_json(request_json: &str) -> String {
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
        "p2a_upload" => match paper2audio::upload_base64(
            &req.file_name,
            &req.voice_id,
            &req.epub_base64,
        ) {
            Ok(resp) => serde_json::to_string(&json!({ "run_id": resp.run_id }))
                .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        "p2a_check_status" => match paper2audio::check_status(&req.run_id) {
            Ok(resp) => serde_json::to_string(&json!({
                "status": resp.status,
                "progress": resp.progress,
                "download_url": resp.download_url,
            }))
            .unwrap_or_else(|_| "{}".into()),
            Err(e) => json!({ "error": e }).to_string(),
        },
        other => json!({ "error": format!("unknown action: {other}") }).to_string(),
    }
}
