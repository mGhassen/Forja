use lan::{LanBindMode, LanServer, PairingState, TorrentHistory, TorrentHistoryEntry};
use std::sync::{Arc, LazyLock, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

static LAN: LazyLock<Mutex<Option<LanServer>>> = LazyLock::new(|| Mutex::new(None));
static LAST_ERROR: LazyLock<Mutex<String>> = LazyLock::new(|| Mutex::new(String::new()));
static HISTORY: LazyLock<TorrentHistory> = LazyLock::new(TorrentHistory::default);

fn set_last_error(msg: &str) {
    if let Ok(mut err) = LAST_ERROR.lock() {
        *err = msg.to_string();
    }
}

fn clear_last_error() {
    if let Ok(mut err) = LAST_ERROR.lock() {
        err.clear();
    }
}

pub fn lan_server_last_error() -> String {
    LAST_ERROR
        .lock()
        .map(|e| e.clone())
        .unwrap_or_default()
}

pub fn lan_server_start(
    runtime: &tokio::runtime::Runtime,
    bind_mode: u8,
    preferred_port: u16,
) -> i32 {
    if let Ok(guard) = LAN.lock() {
        if let Some(existing) = guard.as_ref() {
            let port = existing.port();
            if port > 0 {
                clear_last_error();
                return port as i32;
            }
        }
    }
    // Host (Dart) starts proxy/torrent before LAN. Best-effort here if missing.
    if crate::engine_proxy::proxy_port() == 0 {
        let _ = crate::proxy_start(0);
    }
    #[cfg(feature = "torrent-engine")]
    if crate::torrent_engine_port() == 0 {
        let started = crate::torrent_engine_start(0);
        if started <= 0 {
            let detail = crate::torrent_engine_last_error();
            let msg = if detail.is_empty() {
                "torrent engine not running — start it before LAN server".into()
            } else {
                format!("torrent engine not running: {detail}")
            };
            set_last_error(&msg);
            eprintln!("[lan] start failed: {msg}");
            return -1;
        }
    }
    runtime
        .block_on(async {
            let proxy_state = match crate::engine_proxy::proxy_state() {
                Some(s) => s,
                None => {
                    set_last_error("local proxy not running");
                    eprintln!("[lan] start failed: local proxy not running");
                    return None;
                }
            };
            let torrent = crate::engine_torrent::shared_torrent_engine();
            #[cfg(feature = "torrent-engine")]
            if torrent.engine_port() == 0 {
                set_last_error("torrent engine not running — start it before LAN server");
                eprintln!("[lan] start failed: torrent engine not running");
                return None;
            }
            let server_id = stable_server_id();
            let mut lan = LanServer::new(server_id, proxy_state, torrent);
            restore_paired_devices(&lan.state.pairing);
            restore_torrent_history(&HISTORY);
            lan.state.history = HISTORY.clone();
            lan.set_on_devices_changed(Arc::new(|pairing| {
                persist_paired_devices(pairing);
            }));
            lan.set_on_history_changed(Arc::new(|history| {
                persist_torrent_history(history);
            }));
            let mode = LanBindMode::from_u8(bind_mode);
            match lan.start(mode, preferred_port).await {
                Ok(port) => {
                    *LAN.lock().ok()? = Some(lan);
                    clear_last_error();
                    Some(port)
                }
                Err(e) => {
                    set_last_error(&e);
                    eprintln!("[lan] start failed: {e}");
                    None
                }
            }
        })
        .map(|p| p as i32)
        .unwrap_or(-1)
}

pub fn lan_server_stop(runtime: &tokio::runtime::Runtime) {
    runtime.block_on(async {
        if let Ok(mut guard) = LAN.lock() {
            if let Some(mut server) = guard.take() {
                server.stop().await;
            }
        }
    });
}

pub fn lan_server_port() -> u16 {
    LAN.lock()
        .ok()
        .and_then(|g| g.as_ref().map(|s| s.port()))
        .unwrap_or(0)
}

pub fn lan_pairing_code_refresh() -> String {
    LAN.lock()
        .ok()
        .and_then(|mut g| {
            g.as_mut()
                .map(|s| s.state.pairing.refresh_code())
        })
        .unwrap_or_default()
}

pub fn lan_pairing_code() -> String {
    LAN.lock()
        .ok()
        .and_then(|mut g| g.as_mut().map(|s| s.pairing_code()))
        .unwrap_or_default()
}

pub fn lan_revoke_device(device_id: String) -> bool {
    let ok = LAN
        .lock()
        .ok()
        .and_then(|g| g.as_ref().map(|s| s.state.pairing.revoke_device(&device_id)))
        .unwrap_or(false);
    if ok {
        if let Ok(guard) = LAN.lock() {
            if let Some(server) = guard.as_ref() {
                persist_paired_devices(&server.state.pairing);
            }
        }
    }
    ok
}

pub fn lan_devices_json() -> String {
    LAN.lock()
        .ok()
        .and_then(|g| {
            g.as_ref().map(|s| {
                serde_json::to_string(&s.state.pairing.list_devices())
                    .unwrap_or_else(|_| "[]".into())
            })
        })
        .unwrap_or_else(|| "[]".into())
}

pub fn lan_torrent_history_json() -> String {
    ensure_history_loaded();
    serde_json::to_string(&HISTORY.list()).unwrap_or_else(|_| "[]".into())
}

/// Stop active torrent when matching, delete cached file, drop history row.
pub fn lan_remove_torrent_history(info_hash: String) -> bool {
    if info_hash.is_empty() {
        return false;
    }
    ensure_history_loaded();
    let Some(entry) = HISTORY.remove(&info_hash) else {
        return false;
    };
    persist_torrent_history(&HISTORY);
    if let Ok(guard) = LAN.lock() {
        if let Some(server) = guard.as_ref() {
            server.state.lease.clear_if_hash(&info_hash);
        }
    }
    if let Some(status) = crate::engine_torrent::shared_torrent_engine().status() {
        if status.info_hash.eq_ignore_ascii_case(&entry.info_hash) {
            crate::engine_torrent::torrent_stop();
        }
    }
    if let Some(file) = entry.cache_file.as_deref() {
        let _ = torrent::TorrentEngine::delete_cached_named(file);
    }
    if entry.cache_file.as_deref() != Some(entry.name.as_str()) {
        let _ = torrent::TorrentEngine::delete_cached_named(&entry.name);
    }
    true
}

/// Stop torrent, wipe download cache, clear LAN history.
pub fn lan_clear_torrent_history() -> bool {
    ensure_history_loaded();
    if let Ok(guard) = LAN.lock() {
        if let Some(server) = guard.as_ref() {
            server.state.lease.clear();
        }
    }
    crate::engine_torrent::torrent_stop();
    let _ = torrent::TorrentEngine::clear_cache_dir();
    HISTORY.clear();
    persist_torrent_history(&HISTORY);
    true
}

pub fn lan_browse_servers_json(timeout_ms: u64) -> String {
    let timeout = std::time::Duration::from_millis(timeout_ms.clamp(500, 30_000));
    let servers = lan::browse_forja_servers(timeout);
    serde_json::to_string(&servers).unwrap_or_else(|_| "[]".into())
}

const PAIRED_DEVICES_KEY: &str = "lan_paired_devices";
const TORRENT_HISTORY_KEY: &str = "lan_torrent_history";

fn persist_paired_devices(pairing: &PairingState) {
    let devices = pairing.export_devices();
    let value = serde_json::to_value(devices).unwrap_or(serde_json::json!([]));
    let _ = storage::set(PAIRED_DEVICES_KEY, value);
}

fn restore_paired_devices(pairing: &PairingState) {
    let Some(value) = storage::get(PAIRED_DEVICES_KEY) else {
        return;
    };
    let Ok(devices) = serde_json::from_value::<Vec<lan::DeviceRecord>>(value) else {
        return;
    };
    pairing.restore_devices(devices);
}

fn persist_torrent_history(history: &TorrentHistory) {
    let value = serde_json::to_value(history.list()).unwrap_or(serde_json::json!([]));
    let _ = storage::set(TORRENT_HISTORY_KEY, value);
}

fn restore_torrent_history(history: &TorrentHistory) {
    let Some(value) = storage::get(TORRENT_HISTORY_KEY) else {
        return;
    };
    let Ok(entries) = serde_json::from_value::<Vec<TorrentHistoryEntry>>(value) else {
        return;
    };
    history.restore(entries);
}

fn ensure_history_loaded() {
    static LOADED: LazyLock<Mutex<bool>> = LazyLock::new(|| Mutex::new(false));
    let Ok(mut loaded) = LOADED.lock() else {
        return;
    };
    if *loaded {
        return;
    }
    restore_torrent_history(&HISTORY);
    *loaded = true;
}

fn stable_server_id() -> String {
    if let Some(v) = storage::get("lan_server_id").and_then(|v| v.as_str().map(str::to_string)) {
        return v;
    }
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let id = format!("forja-{nanos:x}");
    let _ = storage::set("lan_server_id", serde_json::Value::String(id.clone()));
    id
}
