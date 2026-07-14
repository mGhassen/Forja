use crate::health_store::ProviderHealthStore;
use crate::request::StreamRequest;

#[derive(Clone, Default)]
pub struct HealthChecker {
    store: ProviderHealthStore,
}

impl HealthChecker {
    pub fn new() -> Self {
        Self {
            store: ProviderHealthStore::global().clone(),
        }
    }

    pub fn memory_key_for_request(request: &StreamRequest, provider_id: &str) -> String {
        ProviderHealthStore::memory_key_for_title(
            request.domain,
            request.tmdb_id,
            request.season,
            request.episode,
            provider_id,
        )
    }

    pub fn record_server_up(&self, request: &StreamRequest, provider_id: &str) {
        let key = Self::memory_key_for_request(request, provider_id);
        self.store.record_server_up(&key);
    }

    pub fn record_server_down(&self, request: &StreamRequest, provider_id: &str) {
        let key = Self::memory_key_for_request(request, provider_id);
        self.store.record_server_failure(&key);
    }

    pub fn record_stream_up(&self, request: &StreamRequest, provider_id: &str) {
        let key = Self::memory_key_for_request(request, provider_id);
        self.store.record_stream_up(&key);
    }

    pub fn record_stream_down(&self, request: &StreamRequest, provider_id: &str) {
        let key = Self::memory_key_for_request(request, provider_id);
        self.store.record_stream_fail(&key);
    }

    pub fn score_for_request(&self, request: &StreamRequest, provider_id: &str) -> i32 {
        let key = Self::memory_key_for_request(request, provider_id);
        self.store.score_for(&key)
    }

    pub fn adjust_domain_score(
        &self,
        request: &StreamRequest,
        provider_id: &str,
        base: u32,
    ) -> u32 {
        let adj = self.score_for_request(request, provider_id);
        let shifted = base as i32 + adj;
        shifted.clamp(0, 100) as u32
    }

    /// Legacy scope label helper — prefer [Self::memory_key_for_request].
    pub fn score(&self, _scope: &str, provider_id: &str) -> i32 {
        self.store.score_for(provider_id)
    }
}

pub fn provider_health_json(payload: &str) -> String {
    crate::health_store::handle_health_json(payload)
}
