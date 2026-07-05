use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use librqbit::{AddTorrent, AddTorrentResponse, ManagedTorrent, Session};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TorrentFile {
    pub path: String,
    pub size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TorrentStatus {
    pub name: String,
    pub progress: f64,
    pub download_rate: u64,
    pub upload_rate: u64,
    pub num_peers: u32,
    pub state: String,
}

struct EngineInner {
    session: Option<Arc<Session>>,
    handle: Option<Arc<ManagedTorrent>>,
    magnet: Option<String>,
}

pub struct TorrentEngine {
    inner: Mutex<EngineInner>,
    runtime: tokio::runtime::Runtime,
}

impl Default for TorrentEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TorrentEngine {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(EngineInner {
                session: None,
                handle: None,
                magnet: None,
            }),
            runtime: tokio::runtime::Runtime::new().expect("tokio runtime"),
        }
    }

    fn download_dir() -> PathBuf {
        std::env::temp_dir().join("forja_torrent")
    }

    pub fn start(&self, magnet: &str) -> Result<(), String> {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return Err("Invalid magnet link".into());
        }
        self.runtime.block_on(async {
            let mut inner = self.inner.lock().map_err(|_| "Engine lock poisoned")?;
            if inner.session.is_none() {
                let session = Session::new(Self::download_dir())
                    .await
                    .map_err(|e| e.to_string())?;
                inner.session = Some(session);
            }
            let session = inner.session.as_ref().unwrap();
            let response = tokio::time::timeout(
                Duration::from_secs(8),
                session.add_torrent(AddTorrent::from_url(magnet), None),
            )
            .await
            .map_err(|_| "Timed out adding torrent".to_string())?
            .map_err(|e| e.to_string())?;
            let handle = match response {
                AddTorrentResponse::Added(_, handle) => handle,
                AddTorrentResponse::AlreadyManaged(_, handle) => handle,
                AddTorrentResponse::ListOnly(_) => {
                    return Err("Magnet resolved as list-only torrent".into());
                }
            };
            inner.handle = Some(handle);
            inner.magnet = Some(magnet.to_string());
            Ok(())
        })
    }

    pub fn stop(&self) {
        let _ = self.runtime.block_on(async {
            let Ok(mut inner) = self.inner.lock() else {
                return;
            };
            if let (Some(session), Some(handle)) = (inner.session.as_ref(), inner.handle.as_ref())
            {
                let _ = session.pause(handle).await;
            }
            inner.handle = None;
            inner.magnet = None;
        });
    }

    pub fn is_running(&self) -> bool {
        self.inner
            .lock()
            .ok()
            .and_then(|inner| {
                inner.handle.as_ref().map(|handle| {
                    let stats = handle.stats();
                    !stats.finished && stats.error.is_none()
                })
            })
            .unwrap_or(false)
    }

    pub fn status(&self) -> Option<TorrentStatus> {
        let inner = self.inner.lock().ok()?;
        let handle = inner.handle.as_ref()?;
        let stats = handle.stats();
        let name = handle
            .name()
            .or_else(|| inner.magnet.clone())
            .unwrap_or_default();
        let progress = if stats.total_bytes == 0 {
            0.0
        } else {
            stats.progress_bytes as f64 / stats.total_bytes as f64
        };
        let (download_rate, upload_rate, num_peers) = if let Some(live) = stats.live.as_ref() {
            (
                (live.download_speed.mbps * 1_000_000.0) as u64,
                (live.upload_speed.mbps * 1_000_000.0) as u64,
                live.snapshot.peer_stats.live as u32,
            )
        } else {
            (0, stats.uploaded_bytes, 0)
        };
        let state = if stats.finished {
            "seeding".into()
        } else if stats.progress_bytes > 0 {
            "downloading".into()
        } else {
            format!("{}", stats.state)
        };
        Some(TorrentStatus {
            name,
            progress,
            download_rate,
            upload_rate,
            num_peers,
            state,
        })
    }

    pub fn status_json(&self) -> String {
        match self.status() {
            Some(s) => serde_json::to_string(&s).unwrap_or_else(|_| "{}".into()),
            None => "null".into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_invalid_magnet() {
        let engine = TorrentEngine::new();
        assert!(engine.start("http://example.com").is_err());
    }

    #[test]
    fn status_none_when_idle() {
        let engine = TorrentEngine::new();
        assert!(engine.status().is_none());
        assert!(!engine.is_running());
    }
}
