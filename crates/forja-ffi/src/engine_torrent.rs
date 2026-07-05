use forja_torrent::TorrentEngine;
use std::sync::{LazyLock, Mutex};

static TORRENT: LazyLock<Mutex<TorrentEngine>> = LazyLock::new(|| Mutex::new(TorrentEngine::new()));

pub fn torrent_start(magnet: String) -> bool {
    TORRENT
        .lock()
        .ok()
        .and_then(|e| e.start(&magnet).ok())
        .is_some()
}

pub fn torrent_stop() {
    if let Ok(e) = TORRENT.lock() {
        e.stop();
    }
}

pub fn torrent_is_running() -> bool {
    TORRENT
        .lock()
        .map(|e| e.is_running())
        .unwrap_or(false)
}

pub fn torrent_status_json() -> String {
    TORRENT
        .lock()
        .map(|e| e.status_json())
        .unwrap_or_else(|_| "null".into())
}

pub fn torrent_engine_start(preferred_port: u16) -> i32 {
    TORRENT
        .lock()
        .ok()
        .and_then(|e| e.start_engine(preferred_port).ok().map(|p| p as i32))
        .unwrap_or(-1)
}

pub fn torrent_engine_port() -> u16 {
    TORRENT
        .lock()
        .map(|e| e.engine_port())
        .unwrap_or(0)
}

pub fn torrent_engine_stop() {
    if let Ok(e) = TORRENT.lock() {
        e.stop_engine();
    }
}

pub fn torrent_stream_json(magnet: String, season: i32, episode: i32, file_idx: i32) -> String {
    let season = if season < 0 { None } else { Some(season) };
    let episode = if episode < 0 { None } else { Some(episode) };
    let file_idx = if file_idx < 0 { None } else { Some(file_idx) };
    TORRENT
        .lock()
        .map(|e| e.stream_magnet_json(&magnet, season, episode, file_idx))
        .unwrap_or_else(|_| r#"{"error":"Engine lock poisoned"}"#.into())
}

pub fn torrent_list_files_json(magnet: String) -> String {
    TORRENT
        .lock()
        .map(|e| e.list_files_json(&magnet))
        .unwrap_or_else(|_| r#"{"error":"Engine lock poisoned"}"#.into())
}
