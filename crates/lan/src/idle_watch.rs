//! When the paired TV that opened a LAN torrent goes idle, pause the swarm;
//! if it stays idle, stop and delete the cached download (same as Settings Delete).

use std::sync::{Arc, Mutex};
use std::time::Duration;

use crate::pairing::PairingState;
use crate::server::{HistoryChangedHook, LanServerState};

/// Same threshold as Settings Online/Idle dots.
pub const DEVICE_IDLE_SECS: u64 = 120;
/// After idle pause, how long before stop + clean if the device stays away.
pub const IDLE_PAUSE_GRACE_SECS: u64 = 120;
const WATCH_INTERVAL: Duration = Duration::from_secs(5);

#[derive(Debug, Clone)]
pub struct LanTorrentLease {
    pub device_id: String,
    pub info_hash: String,
    /// Set when we paused because the owner device went idle.
    pub idle_paused_at: Option<u64>,
}

#[derive(Clone, Default)]
pub struct LanTorrentLeaseStore {
    inner: Arc<Mutex<Option<LanTorrentLease>>>,
}

impl LanTorrentLeaseStore {
    pub fn set(&self, device_id: String, info_hash: String) {
        if device_id.is_empty() || info_hash.is_empty() {
            return;
        }
        if let Ok(mut g) = self.inner.lock() {
            *g = Some(LanTorrentLease {
                device_id,
                info_hash: info_hash.to_ascii_lowercase(),
                idle_paused_at: None,
            });
        }
    }

    pub fn clear(&self) {
        if let Ok(mut g) = self.inner.lock() {
            *g = None;
        }
    }

    pub fn clear_if_hash(&self, info_hash: &str) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        if g.as_ref()
            .is_some_and(|l| l.info_hash.eq_ignore_ascii_case(info_hash))
        {
            *g = None;
        }
    }

    pub fn get(&self) -> Option<LanTorrentLease> {
        self.inner.lock().ok().and_then(|g| g.clone())
    }

    pub fn set_idle_paused_at(&self, at: Option<u64>) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        if let Some(lease) = g.as_mut() {
            lease.idle_paused_at = at;
        }
    }
}

fn unix_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn device_last_seen(pairing: &PairingState, device_id: &str) -> Option<u64> {
    pairing
        .list_devices()
        .into_iter()
        .find(|d| d.device_id == device_id)
        .map(|d| d.last_seen)
}

/// Spawned with the LAN HTTP server; exits when [cancel] flips.
pub async fn run_idle_watch(state: LanServerState, cancel: Arc<std::sync::atomic::AtomicBool>) {
    use std::sync::atomic::Ordering;
    while !cancel.load(Ordering::Relaxed) {
        tokio::time::sleep(WATCH_INTERVAL).await;
        if cancel.load(Ordering::Relaxed) {
            break;
        }
        tick_idle_watch(&state).await;
    }
}

async fn tick_idle_watch(state: &LanServerState) {
    let Some(lease) = state.lease.get() else {
        return;
    };

    let Some(status) = state.torrent.status() else {
        state.lease.clear();
        return;
    };
    if !status.info_hash.eq_ignore_ascii_case(&lease.info_hash) {
        // Another magnet replaced this lease's swarm.
        state.lease.clear_if_hash(&lease.info_hash);
        return;
    }

    let now = unix_secs();
    let idle = match device_last_seen(&state.pairing, &lease.device_id) {
        Some(seen) => now.saturating_sub(seen) > DEVICE_IDLE_SECS,
        None => true, // revoked / gone
    };

    if !idle {
        if lease.idle_paused_at.is_some() {
            state.torrent.unpause_active_on_engine().await;
            state.lease.set_idle_paused_at(None);
            eprintln!(
                "[lan] idle-watch: device {} back — resumed {}",
                lease.device_id,
                short_hash(&lease.info_hash)
            );
        }
        return;
    }

    // Device idle.
    if lease.idle_paused_at.is_none() {
        state.torrent.pause_active_on_engine().await;
        state.lease.set_idle_paused_at(Some(now));
        eprintln!(
            "[lan] idle-watch: device {} idle — paused {}",
            lease.device_id,
            short_hash(&lease.info_hash)
        );
        return;
    }

    let paused_at = lease.idle_paused_at.unwrap_or(now);
    if now.saturating_sub(paused_at) < IDLE_PAUSE_GRACE_SECS {
        return;
    }

    eprintln!(
        "[lan] idle-watch: device {} still idle — stop+clean {}",
        lease.device_id,
        short_hash(&lease.info_hash)
    );
    clean_lease_torrent(state, &lease.info_hash).await;
}

async fn clean_lease_torrent(state: &LanServerState, info_hash: &str) {
    let entry = state.history.remove(info_hash);
    state.torrent.stop_on_engine().await;
    state.lease.clear();
    if let Some(entry) = entry {
        if let Some(file) = entry.cache_file.as_deref() {
            let _ = torrent::TorrentEngine::delete_cached_named(file);
        }
        if entry.cache_file.as_deref() != Some(entry.name.as_str()) {
            let _ = torrent::TorrentEngine::delete_cached_named(&entry.name);
        }
        notify_history(state);
    } else {
        // No history row — still wiped active swarm above.
        notify_history(state);
    }
}

fn notify_history(state: &LanServerState) {
    if let Some(hook) = &state.on_history_changed {
        let hook: HistoryChangedHook = Arc::clone(hook);
        hook(&state.history);
    }
}

fn short_hash(hash: &str) -> &str {
    if hash.len() > 8 {
        &hash[..8]
    } else {
        hash
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lease_set_clear_and_pause_flag() {
        let store = LanTorrentLeaseStore::default();
        store.set("tv1".into(), "ABCDEF".into());
        let l = store.get().unwrap();
        assert_eq!(l.device_id, "tv1");
        assert_eq!(l.info_hash, "abcdef");
        assert!(l.idle_paused_at.is_none());
        store.set_idle_paused_at(Some(100));
        assert_eq!(store.get().unwrap().idle_paused_at, Some(100));
        store.clear_if_hash("abcdef");
        assert!(store.get().is_none());
    }
}
