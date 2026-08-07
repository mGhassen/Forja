use lan::{LanBindMode, LanServer};
use std::sync::{LazyLock, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

static LAN: LazyLock<Mutex<Option<LanServer>>> = LazyLock::new(|| Mutex::new(None));
static LAST_ERROR: LazyLock<Mutex<String>> = LazyLock::new(|| Mutex::new(String::new()));

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
    if crate::engine_proxy::proxy_port() == 0 {
        let _ = crate::proxy_start(preferred_port as u32);
    }
    #[cfg(feature = "torrent-engine")]
    if crate::torrent_engine_port() == 0 {
        let _ = crate::torrent_engine_start(preferred_port as u32);
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
            let server_id = stable_server_id();
            let mut lan = LanServer::new(server_id, proxy_state, torrent);
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

pub fn lan_server_stop() {
    if let Ok(mut guard) = LAN.lock() {
        if let Some(mut server) = guard.take() {
            server.stop();
        }
    }
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
        .and_then(|mut g| g.as_mut().map(|s| s.pairing_code()))
        .unwrap_or_default()
}

pub fn lan_revoke_device(device_id: String) -> bool {
    LAN.lock()
        .ok()
        .and_then(|g| g.as_ref().map(|s| s.state.pairing.revoke_device(&device_id)))
        .unwrap_or(false)
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

pub fn lan_browse_servers_json(timeout_ms: u64) -> String {
    let timeout = std::time::Duration::from_millis(timeout_ms.clamp(500, 30_000));
    let servers = lan::browse_forja_servers(timeout);
    serde_json::to_string(&servers).unwrap_or_else(|_| "[]".into())
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
