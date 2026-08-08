use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

const MAX_ENTRIES: usize = 50;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TorrentHistoryEntry {
    pub info_hash: String,
    pub name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cache_file: Option<String>,
    pub device_id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub device_label: Option<String>,
    pub opened_at: u64,
    #[serde(default)]
    pub total_bytes: u64,
}

#[derive(Clone, Default)]
pub struct TorrentHistory {
    inner: Arc<Mutex<Vec<TorrentHistoryEntry>>>,
}

impl TorrentHistory {
    pub fn record(&self, entry: TorrentHistoryEntry) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        g.retain(|e| !e.info_hash.eq_ignore_ascii_case(&entry.info_hash));
        g.insert(0, entry);
        if g.len() > MAX_ENTRIES {
            g.truncate(MAX_ENTRIES);
        }
    }

    pub fn list(&self) -> Vec<TorrentHistoryEntry> {
        self.inner.lock().map(|g| g.clone()).unwrap_or_default()
    }

    pub fn remove(&self, info_hash: &str) -> Option<TorrentHistoryEntry> {
        let Ok(mut g) = self.inner.lock() else {
            return None;
        };
        let idx = g
            .iter()
            .position(|e| e.info_hash.eq_ignore_ascii_case(info_hash))?;
        Some(g.remove(idx))
    }

    pub fn clear(&self) {
        if let Ok(mut g) = self.inner.lock() {
            g.clear();
        }
    }

    pub fn restore(&self, entries: Vec<TorrentHistoryEntry>) {
        let Ok(mut g) = self.inner.lock() else {
            return;
        };
        *g = entries;
        if g.len() > MAX_ENTRIES {
            g.truncate(MAX_ENTRIES);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn record_dedupes_by_hash_and_caps() {
        let h = TorrentHistory::default();
        for i in 0..60 {
            h.record(TorrentHistoryEntry {
                info_hash: format!("hash{i:02}"),
                name: format!("n{i}"),
                cache_file: None,
                device_id: "tv".into(),
                device_label: None,
                opened_at: i,
                total_bytes: 0,
            });
        }
        h.record(TorrentHistoryEntry {
            info_hash: "hash05".into(),
            name: "updated".into(),
            cache_file: Some("a.mkv".into()),
            device_id: "tv".into(),
            device_label: Some("Living Room".into()),
            opened_at: 99,
            total_bytes: 10,
        });
        let list = h.list();
        assert_eq!(list.len(), MAX_ENTRIES);
        assert_eq!(list[0].info_hash, "hash05");
        assert_eq!(list[0].name, "updated");
        assert_eq!(list[0].opened_at, 99);
    }
}
