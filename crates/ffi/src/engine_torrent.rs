use torrent::TorrentEngine;
use std::sync::{Arc, LazyLock, Mutex};

/// Engine is internally synchronized (`TorrentEngine.inner`). Do **not** wrap
/// long `stream_magnet` / `list_files` calls in an outer mutex — that blocked
/// `status_json` (and the next play) for the whole magnet/head wait.
static TORRENT: LazyLock<Arc<TorrentEngine>> =
    LazyLock::new(|| Arc::new(TorrentEngine::new()));
static LAST_ENGINE_ERROR: LazyLock<Mutex<String>> = LazyLock::new(|| Mutex::new(String::new()));

pub fn shared_torrent_engine() -> Arc<TorrentEngine> {
    TORRENT.clone()
}

fn set_last_error(msg: &str) {
    if let Ok(mut err) = LAST_ENGINE_ERROR.lock() {
        *err = msg.to_string();
    }
}

pub fn torrent_start(magnet: String) -> bool {
    TORRENT.start(&magnet).is_ok()
}

pub fn torrent_stop() {
    TORRENT.stop();
}

pub fn torrent_is_running() -> bool {
    TORRENT.is_running()
}

pub fn torrent_status_json() -> String {
    TORRENT.status_json()
}

pub fn torrent_engine_start(preferred_port: u16) -> i32 {
    match TORRENT.start_engine(preferred_port) {
        Ok(port) => {
            if let Ok(mut err) = LAST_ENGINE_ERROR.lock() {
                err.clear();
            }
            port as i32
        }
        Err(msg) => {
            set_last_error(&msg);
            eprintln!("[torrent] engine start failed: {msg}");
            -1
        }
    }
}

pub fn torrent_engine_last_error() -> String {
    LAST_ENGINE_ERROR
        .lock()
        .map(|e| e.clone())
        .unwrap_or_default()
}

pub fn torrent_engine_port() -> u16 {
    TORRENT.engine_port()
}

pub fn torrent_engine_stop() {
    TORRENT.stop_engine();
}

pub fn torrent_set_peer_limit(limit: u32) {
    TORRENT.set_peer_limit(limit);
}

pub fn torrent_set_disk_cache_bytes(bytes: u64) {
    TORRENT.set_disk_cache_capacity_bytes(bytes);
}

pub fn torrent_reclaim_disk_cache_json(target_bytes: u64) -> String {
    TORRENT.reclaim_disk_cache_json(target_bytes)
}

pub fn torrent_stream_json(magnet: String, season: i32, episode: i32, file_idx: i32) -> String {
    let season = if season < 0 { None } else { Some(season) };
    let episode = if episode < 0 { None } else { Some(episode) };
    let file_idx = if file_idx < 0 { None } else { Some(file_idx) };
    TORRENT.stream_magnet_json(&magnet, season, episode, file_idx)
}

pub fn torrent_list_files_json(magnet: String) -> String {
    TORRENT.list_files_json(&magnet)
}
