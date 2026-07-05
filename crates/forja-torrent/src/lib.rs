use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};

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

pub struct TorrentEngine {
    running: AtomicBool,
    magnet: Option<String>,
}

impl Default for TorrentEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TorrentEngine {
    pub fn new() -> Self {
        Self {
            running: AtomicBool::new(false),
            magnet: None,
        }
    }

    pub fn start(&mut self, magnet: &str) -> Result<(), String> {
        if magnet.is_empty() || !magnet.starts_with("magnet:") {
            return Err("Invalid magnet link".into());
        }
        self.magnet = Some(magnet.to_string());
        self.running.store(true, Ordering::SeqCst);
        Ok(())
    }

    pub fn stop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
        self.magnet = None;
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::SeqCst)
    }

    pub fn status(&self) -> Option<TorrentStatus> {
        if !self.is_running() {
            return None;
        }
        Some(TorrentStatus {
            name: self.magnet.clone().unwrap_or_default(),
            progress: 0.0,
            download_rate: 0,
            upload_rate: 0,
            num_peers: 0,
            state: "downloading".into(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn starts_valid_magnet() {
        let mut engine = TorrentEngine::new();
        assert!(engine
            .start("magnet:?xt=urn:btih:abc")
            .is_ok());
        assert!(engine.is_running());
        engine.stop();
        assert!(!engine.is_running());
    }
}
