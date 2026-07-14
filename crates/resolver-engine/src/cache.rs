use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use stream::PlayableSource;

#[derive(Clone)]
struct CacheEntry {
    sources: Vec<PlayableSource>,
    provider_id: String,
    expires: Instant,
}

#[derive(Clone, Default)]
pub struct ResolveCache {
    inner: Arc<Mutex<HashMap<String, CacheEntry>>>,
    ttl: Duration,
}

impl ResolveCache {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(HashMap::new())),
            ttl: Duration::from_secs(3600),
        }
    }

    fn cache_key(
        domain: &str,
        tmdb_id: i64,
        season: i32,
        episode: i32,
        provider_id: &str,
    ) -> String {
        format!("{domain}:{tmdb_id}:{season}:{episode}:{provider_id}")
    }

    pub fn get(
        &self,
        domain: &str,
        tmdb_id: i64,
        season: i32,
        episode: i32,
        provider_id: &str,
    ) -> Option<(String, Vec<PlayableSource>)> {
        let key = Self::cache_key(domain, tmdb_id, season, episode, provider_id);
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let entry = g.get(&key)?;
        if Instant::now() >= entry.expires {
            g.remove(&key);
            return None;
        }
        Some((entry.provider_id.clone(), entry.sources.clone()))
    }

    pub fn put(
        &self,
        domain: &str,
        tmdb_id: i64,
        season: i32,
        episode: i32,
        provider_id: &str,
        sources: Vec<PlayableSource>,
    ) {
        let key = Self::cache_key(domain, tmdb_id, season, episode, provider_id);
        let entry = CacheEntry {
            sources,
            provider_id: provider_id.to_string(),
            expires: Instant::now() + self.ttl,
        };
        self.inner
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(key, entry);
    }

    pub fn invalidate_provider(&self, provider_id: &str) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.retain(|_, v| v.provider_id != provider_id);
    }
}
