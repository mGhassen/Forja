use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

use crate::sport_match::Candidate;

const EPG_CACHE_TTL: Duration = Duration::from_secs(300);

struct EpgCacheEntry {
    description: String,
    start_timestamp: Option<f64>,
    fetched_at: Instant,
}

fn epg_cache() -> &'static Mutex<HashMap<String, EpgCacheEntry>> {
    static CACHE: OnceLock<Mutex<HashMap<String, EpgCacheEntry>>> = OnceLock::new();
    CACHE.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn portal_epg_key(portal_key: &str, stream_id: &str) -> String {
    format!("{portal_key}|{stream_id}")
}

pub fn apply_cached_epg(portal_key: &str, candidates: &mut [Candidate]) {
    let Ok(cache) = epg_cache().lock() else {
        return;
    };
    for c in candidates.iter_mut() {
        if !c.description.is_empty() {
            continue;
        }
        let key = portal_epg_key(portal_key, &c.stream_id);
        let Some(entry) = cache.get(&key) else {
            continue;
        };
        if entry.fetched_at.elapsed() >= EPG_CACHE_TTL {
            continue;
        }
        c.description = entry.description.clone();
        c.start_timestamp = entry.start_timestamp;
    }
}

pub fn store_candidate_epg(portal_key: &str, candidates: &[Candidate], indices: &[usize]) {
    let Ok(mut cache) = epg_cache().lock() else {
        return;
    };
    let now = Instant::now();
    for &idx in indices {
        let Some(c) = candidates.get(idx) else {
            continue;
        };
        if c.stream_id.is_empty() || c.description.is_empty() {
            continue;
        }
        cache.insert(
            portal_epg_key(portal_key, &c.stream_id),
            EpgCacheEntry {
                description: c.description.clone(),
                start_timestamp: c.start_timestamp,
                fetched_at: now,
            },
        );
    }
}
