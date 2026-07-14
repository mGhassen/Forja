use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use serde::{Deserialize, Serialize};
use serde_json::json;
use stream::SourceDomain;

const STORAGE_KEY: &str = "provider_score_reliability_v5";

pub const SERVER_FAIL_DELTA: i32 = -2;
pub const SERVER_UP_DELTA: i32 = 2;
pub const STREAM_UP_DELTA: i32 = 2;
pub const STREAM_FAIL_DELTA: i32 = -2;

#[derive(Debug, Clone, Default)]
struct HealthState {
    server: HashMap<String, i32>,
    stream: HashMap<String, i32>,
    last_delta: HashMap<String, i32>,
    loaded: bool,
}

#[derive(Clone)]
pub struct ProviderHealthStore {
    inner: Arc<Mutex<HealthState>>,
}

impl Default for ProviderHealthStore {
    fn default() -> Self {
        Self::new()
    }
}

impl ProviderHealthStore {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(HealthState::default())),
        }
    }

    pub fn global() -> &'static ProviderHealthStore {
        static STORE: std::sync::LazyLock<ProviderHealthStore> =
            std::sync::LazyLock::new(ProviderHealthStore::new);
        &STORE
    }

    fn ensure_loaded(&self) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        if g.loaded {
            return;
        }
        if let Some(raw) = storage::get(STORAGE_KEY) {
            if let Some(obj) = raw.as_object() {
                read_verdict_map(obj.get("srv"), &mut g.server);
                read_verdict_map(obj.get("str"), &mut g.stream);
                read_delta_map(obj.get("d"), &mut g.last_delta);
            }
        }
        g.loaded = true;
    }

    fn persist(&self) {
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let value = json!({
            "srv": g.server,
            "str": g.stream,
            "d": g.last_delta,
        });
        let _ = storage::set(STORAGE_KEY, value);
    }

    pub fn reset_for_test(&self) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.server.clear();
        g.stream.clear();
        g.last_delta.clear();
        g.loaded = true;
    }

    /// Clear all reliability memory and persist empty maps (Settings cleaner).
    pub fn clear_all(&self) {
        {
            let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
            g.server.clear();
            g.stream.clear();
            g.last_delta.clear();
            g.loaded = true;
        }
        self.persist();
    }

    pub fn normalize_provider_id(provider_id: &str) -> String {
        let id = provider_id.trim();
        if id.is_empty() {
            return String::new();
        }
        let lower = id.to_ascii_lowercase();
        if lower.ends_with(":sub") || lower.ends_with(":dub") {
            id[..id.rfind(':').unwrap_or(id.len())].to_string()
        } else {
            id.to_string()
        }
    }

    pub fn memory_key_for_title(
        domain: SourceDomain,
        content_id: i64,
        season: i32,
        episode: i32,
        provider_id: &str,
    ) -> String {
        let norm = Self::normalize_provider_id(provider_id);
        match domain {
            SourceDomain::Movies => format!("movie:{content_id}:{norm}"),
            SourceDomain::Series => format!("tv:{content_id}:s{season}e{episode}:{norm}"),
            SourceDomain::Anime => format!("anime:{content_id}:e{episode}:{norm}"),
            _ => format!("{domain:?}:{content_id}:{norm}"),
        }
    }

    pub fn score_for(&self, memory_key: &str) -> i32 {
        self.ensure_loaded();
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        total_for(&g, memory_key)
    }

    pub fn server_verdict_for(&self, memory_key: &str) -> Option<i32> {
        self.ensure_loaded();
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.server.get(memory_key).copied()
    }

    pub fn stream_verdict_for(&self, memory_key: &str) -> Option<i32> {
        self.ensure_loaded();
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.stream.get(memory_key).copied()
    }

    pub fn last_delta_for(&self, memory_key: &str) -> Option<i32> {
        self.ensure_loaded();
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.last_delta.get(memory_key).copied()
    }

    /// Sum of per-title totals for one provider across all films / episodes.
    pub fn global_score_for(&self, provider_id: &str) -> i32 {
        let norm = Self::normalize_provider_id(provider_id);
        if norm.is_empty() {
            return 0;
        }
        *self.all_provider_totals().get(&norm).unwrap_or(&0)
    }

    /// Provider id → sum of that provider's title scores (floored totals).
    pub fn all_provider_totals(&self) -> HashMap<String, i32> {
        self.ensure_loaded();
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        aggregate_provider_totals(&g)
    }

    pub fn record_server_up(&self, memory_key: &str) -> i32 {
        self.set_verdict(memory_key, Some(SERVER_UP_DELTA), None, false)
    }

    pub fn record_server_failure(&self, memory_key: &str) -> i32 {
        self.set_verdict(memory_key, Some(SERVER_FAIL_DELTA), None, false)
    }

    pub fn record_stream_up(&self, memory_key: &str) -> i32 {
        self.set_verdict(memory_key, None, Some(STREAM_UP_DELTA), true)
    }

    pub fn record_stream_up_with_wins(&self, memory_key: &str, stream_wins: bool) -> i32 {
        self.set_verdict(memory_key, None, Some(STREAM_UP_DELTA), stream_wins)
    }

    pub fn record_stream_fail(&self, memory_key: &str) -> i32 {
        self.set_verdict(memory_key, None, Some(STREAM_FAIL_DELTA), false)
    }

    fn set_verdict(
        &self,
        memory_key: &str,
        server: Option<i32>,
        stream: Option<i32>,
        stream_wins: bool,
    ) -> i32 {
        if memory_key.is_empty() {
            return 0;
        }
        self.ensure_loaded();
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let before = total_for(&g, memory_key);
        let mut changed = false;

        if let Some(server_delta) = server {
            if g.server.get(memory_key).copied() != Some(server_delta) {
                g.server.insert(memory_key.to_string(), server_delta);
                changed = true;
            }
        }
        if let Some(stream_delta) = stream {
            let current = g.stream.get(memory_key).copied();
            let blocked_by_win =
                !stream_wins && stream_delta < 0 && current == Some(STREAM_UP_DELTA);
            if !blocked_by_win && current != Some(stream_delta) {
                g.stream.insert(memory_key.to_string(), stream_delta);
                changed = true;
            }
        }

        if !changed {
            return before;
        }

        let after = total_for(&g, memory_key);
        let delta = after - before;
        let fallback = g.last_delta.get(memory_key).copied().unwrap_or(0);
        g.last_delta.insert(
            memory_key.to_string(),
            if delta != 0 {
                delta
            } else {
                stream.or(server).unwrap_or(fallback)
            },
        );
        drop(g);
        self.persist();
        after
    }
}

fn total_for(g: &HealthState, key: &str) -> i32 {
    ((g.server.get(key).copied().unwrap_or(0) + g.stream.get(key).copied().unwrap_or(0)).max(0))
        as i32
}

/// Extract provider id from a memory key (`movie:550:vixsrc`, `tv:1:s1e2:nuvio:x`, …).
pub fn provider_from_memory_key(key: &str) -> Option<String> {
    let parts: Vec<&str> = key.split(':').collect();
    match parts.first().copied()? {
        "movie" if parts.len() >= 3 => Some(parts[2..].join(":")),
        "tv" if parts.len() >= 4 => Some(parts[3..].join(":")),
        "anime" if parts.len() >= 4 => Some(parts[3..].join(":")),
        _ if parts.len() >= 3 => Some(parts[2..].join(":")),
        _ => None,
    }
    .filter(|s| !s.is_empty())
}

fn aggregate_provider_totals(g: &HealthState) -> HashMap<String, i32> {
    let mut keys = std::collections::HashSet::new();
    keys.extend(g.server.keys().cloned());
    keys.extend(g.stream.keys().cloned());
    let mut out: HashMap<String, i32> = HashMap::new();
    for key in keys {
        let Some(provider) = provider_from_memory_key(&key) else {
            continue;
        };
        let t = total_for(g, &key);
        if t == 0 {
            continue;
        }
        *out.entry(provider).or_default() += t;
    }
    out
}

fn read_verdict_map(raw: Option<&serde_json::Value>, into: &mut HashMap<String, i32>) {
    let Some(obj) = raw.and_then(|v| v.as_object()) else {
        return;
    };
    for (k, v) in obj {
        let Some(n) = v.as_i64() else {
            continue;
        };
        if n == 0 {
            continue;
        }
        into.insert(k.clone(), (n as i32).clamp(-2, 2));
    }
}

fn read_delta_map(raw: Option<&serde_json::Value>, into: &mut HashMap<String, i32>) {
    let Some(obj) = raw.and_then(|v| v.as_object()) else {
        return;
    };
    for (k, v) in obj {
        let Some(n) = v.as_i64() else {
            continue;
        };
        if n == 0 {
            continue;
        }
        into.insert(k.clone(), n as i32);
    }
}

fn default_stream_wins() -> bool {
    true
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct HealthActionRequest {
    action: String,
    #[serde(default)]
    memory_key: String,
    #[serde(default)]
    provider_id: String,
    #[serde(default = "default_stream_wins")]
    stream_wins: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct HealthQueryResponse {
    score: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    server_verdict: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    stream_verdict: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_delta: Option<i32>,
}

pub fn handle_health_json(payload: &str) -> String {
    let req: HealthActionRequest = match serde_json::from_str(payload) {
        Ok(v) => v,
        Err(e) => return serde_json::json!({ "error": e.to_string() }).to_string(),
    };
    let store = ProviderHealthStore::global();
    match req.action.as_str() {
        "resetForTest" => {
            store.reset_for_test();
            r#"{"ok":true}"#.into()
        }
        "clearAll" => {
            store.clear_all();
            r#"{"ok":true}"#.into()
        }
        "recordServerUp" => {
            let score = store.record_server_up(&req.memory_key);
            serde_json::to_string(&HealthQueryResponse {
                score,
                server_verdict: store.server_verdict_for(&req.memory_key),
                stream_verdict: store.stream_verdict_for(&req.memory_key),
                last_delta: store.last_delta_for(&req.memory_key),
            })
            .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string())
        }
        "recordServerFailure" => {
            let score = store.record_server_failure(&req.memory_key);
            serde_json::to_string(&HealthQueryResponse {
                score,
                server_verdict: store.server_verdict_for(&req.memory_key),
                stream_verdict: store.stream_verdict_for(&req.memory_key),
                last_delta: store.last_delta_for(&req.memory_key),
            })
            .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string())
        }
        "recordStreamUp" => {
            let score = store.record_stream_up_with_wins(&req.memory_key, req.stream_wins);
            serde_json::to_string(&HealthQueryResponse {
                score,
                server_verdict: store.server_verdict_for(&req.memory_key),
                stream_verdict: store.stream_verdict_for(&req.memory_key),
                last_delta: store.last_delta_for(&req.memory_key),
            })
            .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string())
        }
        "recordStreamFail" => {
            let score = store.record_stream_fail(&req.memory_key);
            serde_json::to_string(&HealthQueryResponse {
                score,
                server_verdict: store.server_verdict_for(&req.memory_key),
                stream_verdict: store.stream_verdict_for(&req.memory_key),
                last_delta: store.last_delta_for(&req.memory_key),
            })
            .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string())
        }
        "query" => serde_json::to_string(&HealthQueryResponse {
            score: store.score_for(&req.memory_key),
            server_verdict: store.server_verdict_for(&req.memory_key),
            stream_verdict: store.stream_verdict_for(&req.memory_key),
            last_delta: store.last_delta_for(&req.memory_key),
        })
        .unwrap_or_else(|e| serde_json::json!({ "error": e.to_string() }).to_string()),
        "queryGlobal" => {
            let score = store.global_score_for(&req.provider_id);
            serde_json::json!({ "score": score, "providerId": ProviderHealthStore::normalize_provider_id(&req.provider_id) }).to_string()
        }
        "queryGlobalAll" => {
            let totals = store.all_provider_totals();
            serde_json::json!({ "totals": totals }).to_string()
        }
        other => serde_json::json!({ "error": format!("unknown action {other}") }).to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn netted_verdicts_match_dart_model() {
        let store = ProviderHealthStore::new();
        store.reset_for_test();
        let key = "movie:550:vixsrc";
        assert_eq!(store.score_for(key), 0);
        store.record_server_up(key);
        assert_eq!(store.score_for(key), 2);
        store.record_stream_up(key);
        assert_eq!(store.score_for(key), 4);
        store.record_stream_fail(key);
        assert_eq!(store.score_for(key), 4);
        assert!(store.last_delta_for(key).is_none() || store.last_delta_for(key) == Some(2));
    }

    #[test]
    fn stream_up_is_sticky_against_fail() {
        let store = ProviderHealthStore::new();
        store.reset_for_test();
        let key = "movie:1:vidlink";
        store.record_stream_up(key);
        store.record_stream_fail(key);
        assert_eq!(store.score_for(key), 2);
    }

    #[test]
    fn global_score_sums_across_titles() {
        let store = ProviderHealthStore::new();
        store.reset_for_test();
        store.record_server_up("movie:1:vixsrc");
        store.record_stream_up("movie:1:vixsrc");
        store.record_server_up("movie:2:vixsrc");
        store.record_stream_up("movie:2:vixsrc");
        store.record_server_up("movie:2:vidlink");
        assert_eq!(store.score_for("movie:1:vixsrc"), 4);
        assert_eq!(store.score_for("movie:2:vixsrc"), 4);
        assert_eq!(store.global_score_for("vixsrc"), 8);
        assert_eq!(store.global_score_for("vidlink"), 2);
        assert_eq!(store.global_score_for("videasy"), 0);
    }

    #[test]
    fn provider_from_memory_key_handles_nested_ids() {
        assert_eq!(
            provider_from_memory_key("movie:10:nuvio:torrentio").as_deref(),
            Some("nuvio:torrentio")
        );
        assert_eq!(
            provider_from_memory_key("tv:1399:s1e3:vidlink").as_deref(),
            Some("vidlink")
        );
        assert_eq!(
            provider_from_memory_key("anime:21:e12:miruro:bee").as_deref(),
            Some("miruro:bee")
        );
    }
}
