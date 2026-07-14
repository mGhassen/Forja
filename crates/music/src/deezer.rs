use std::time::Duration;

use serde_json::Value;

use crate::http::{block_on, client};
use crate::types::{MusicAlbum, MusicTrack};

const TIMEOUT: Duration = Duration::from_secs(15);
const MAX_RETRIES: u32 = 5;

pub fn search_tracks(query: &str) -> Result<Vec<MusicTrack>, String> {
    block_on(with_retry(
        || async {
            let url = format!(
                "https://api.deezer.com/search?q={}",
                urlencoding::encode(query)
            );
            fetch_tracks(&url).await
        },
        MAX_RETRIES,
    ))
}

pub fn trending_tracks(index: u32, limit: u32) -> Result<Vec<MusicTrack>, String> {
    block_on(with_retry(
        || async {
            let url = format!(
                "https://api.deezer.com/chart/0/tracks?index={index}&limit={limit}"
            );
            fetch_tracks(&url).await
        },
        MAX_RETRIES,
    ))
}

pub fn search_albums(query: &str) -> Result<Vec<MusicAlbum>, String> {
    block_on(with_retry(
        || async {
            let url = format!(
                "https://api.deezer.com/search/album?q={}",
                urlencoding::encode(query)
            );
            fetch_albums(&url).await
        },
        MAX_RETRIES,
    ))
}

pub fn album_tracks(album_id: &str) -> Result<Vec<MusicTrack>, String> {
    block_on(with_retry(
        || async {
            let url = format!("https://api.deezer.com/album/{album_id}");
            let http = client(TIMEOUT)?;
            let response = http.get(&url).send().await.map_err(|e| e.to_string())?;
            if !response.status().is_success() {
                return Err(format!("deezer album HTTP {}", response.status()));
            }
            let data: Value = response.json().await.map_err(|e| e.to_string())?;
            let album_title = str_field(&data, "title");
            let album_cover = cover_from(&data);
            let items = data
                .get("tracks")
                .and_then(|t| t.get("data"))
                .and_then(|d| d.as_array())
                .cloned()
                .unwrap_or_default();
            Ok(items
                .iter()
                .map(|track| {
                    let mut normalized = track_track(track);
                    normalized.album = album_title.clone();
                    if !album_cover.is_empty() {
                        normalized.cover = album_cover.clone();
                    }
                    normalized
                })
                .collect())
        },
        MAX_RETRIES,
    ))
}

pub fn related_tracks(track_id: &str) -> Result<Vec<MusicTrack>, String> {
    block_on(with_retry(
        || async {
            let url = format!("https://api.deezer.com/track/{track_id}/related");
            fetch_tracks(&url).await
        },
        MAX_RETRIES,
    ))
}

async fn fetch_tracks(url: &str) -> Result<Vec<MusicTrack>, String> {
    let http = client(TIMEOUT)?;
    let response = http.get(url).send().await.map_err(|e| e.to_string())?;
    if !response.status().is_success() {
        return Err(format!("deezer HTTP {}", response.status()));
    }
    let data: Value = response.json().await.map_err(|e| e.to_string())?;
    let items = data
        .get("data")
        .and_then(|d| d.as_array())
        .cloned()
        .unwrap_or_default();
    Ok(items.iter().map(track_track).collect())
}

async fn fetch_albums(url: &str) -> Result<Vec<MusicAlbum>, String> {
    let http = client(TIMEOUT)?;
    let response = http.get(url).send().await.map_err(|e| e.to_string())?;
    if !response.status().is_success() {
        return Err(format!("deezer HTTP {}", response.status()));
    }
    let data: Value = response.json().await.map_err(|e| e.to_string())?;
    let items = data
        .get("data")
        .and_then(|d| d.as_array())
        .cloned()
        .unwrap_or_default();
    Ok(items.iter().map(album_album).collect())
}

async fn with_retry<T, F, Fut>(mut f: F, max_retries: u32) -> Result<T, String>
where
    F: FnMut() -> Fut,
    Fut: std::future::Future<Output = Result<T, String>>,
    T: serde::Serialize,
{
    let mut last_err = "deezer request failed".to_string();
    for attempt in 1..=max_retries {
        match f().await {
            Ok(result) => {
                if let Ok(empty) = serde_json::to_value(&result) {
                    if empty.as_array().is_some_and(|a| a.is_empty()) && attempt < max_retries {
                        tokio::time::sleep(Duration::from_millis(300 * attempt as u64)).await;
                        continue;
                    }
                }
                return Ok(result);
            }
            Err(e) => {
                last_err = e;
                if attempt < max_retries {
                    tokio::time::sleep(Duration::from_millis(300 * attempt as u64)).await;
                }
            }
        }
    }
    Err(last_err)
}

fn track_track(item: &Value) -> MusicTrack {
    let artist = item
        .get("artist")
        .map(|a| str_field(a, "name"))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Unknown Artist".into());
    let album_obj = item.get("album");
    let album = album_obj
        .map(|a| str_field(a, "title"))
        .unwrap_or_default();
    let cover = album_obj
        .map(cover_from)
        .filter(|s| !s.is_empty())
        .or_else(|| str_field_opt(item, "cover"))
        .unwrap_or_default();
    MusicTrack {
        id: item
            .get("id")
            .map(|v| v.to_string().trim_matches('"').to_string())
            .unwrap_or_default(),
        title: str_field(item, "title"),
        artist,
        album,
        cover,
        duration: item.get("duration").and_then(|v| v.as_i64()).unwrap_or(0),
    }
}

fn album_album(item: &Value) -> MusicAlbum {
    MusicAlbum {
        id: item
            .get("id")
            .map(|v| v.to_string().trim_matches('"').to_string())
            .unwrap_or_default(),
        title: str_field(item, "title"),
        artist: item
            .get("artist")
            .map(|a| str_field(a, "name"))
            .unwrap_or_else(|| "Unknown Artist".into()),
        cover: cover_from(item),
        nb_tracks: item.get("nb_tracks").and_then(|v| v.as_i64()),
    }
}

fn cover_from(obj: &Value) -> String {
    ["cover_xl", "cover_big", "cover_medium", "cover_small"]
        .iter()
        .find_map(|k| str_field_opt(obj, k))
        .unwrap_or_default()
}

fn str_field(obj: &Value, key: &str) -> String {
    str_field_opt(obj, key).unwrap_or_default()
}

fn str_field_opt(obj: &Value, key: &str) -> Option<String> {
    obj.get(key).and_then(|v| match v {
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn normalizes_track() {
        let track = track_track(&json!({
            "id": 1,
            "title": "Song",
            "duration": 200,
            "artist": { "name": "Artist" },
            "album": { "title": "Album", "cover_xl": "http://cover" }
        }));
        assert_eq!(track.title, "Song");
        assert_eq!(track.artist, "Artist");
        assert_eq!(track.album, "Album");
        assert_eq!(track.cover, "http://cover");
    }
}
