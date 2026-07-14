use std::sync::Arc;

use stream::{order_providers, OrderProvidersRequest, SourceDomain};

use crate::health_store::ProviderHealthStore;
use crate::plugins;
use crate::provider::{Provider, ProviderKind};

pub struct ProviderRegistry {
    providers: Vec<Arc<dyn Provider>>,
}

impl ProviderRegistry {
    pub fn built_in() -> Self {
        Self {
            providers: plugins::built_in(),
        }
    }

    pub fn get(&self, id: &str) -> Option<Arc<dyn Provider>> {
        self.providers.iter().find(|p| p.id() == id).cloned()
    }

    pub fn ordered_ids(
        &self,
        domain: SourceDomain,
        candidate_ids: &[String],
        settings_order: &[String],
        preferred: &str,
    ) -> Vec<String> {
        let response = order_providers(OrderProvidersRequest {
            domain,
            candidate_ids: candidate_ids.to_vec(),
            settings_order: settings_order.to_vec(),
            preferred: preferred.to_string(),
            reliability: ProviderHealthStore::global().all_provider_totals(),
        });
        response.ordered_ids
    }

    pub fn filter_enabled(&self, ids: &[String], enabled: &[String]) -> Vec<String> {
        if enabled.is_empty() {
            return ids.to_vec();
        }
        let set: std::collections::HashSet<&str> = enabled.iter().map(|s| s.as_str()).collect();
        ids.iter()
            .filter(|id| set.contains(id.as_str()) || id.starts_with("nuvio:"))
            .cloned()
            .collect()
    }

    pub fn is_host_required(&self, id: &str) -> bool {
        let lookup = if id.starts_with("nuvio:") {
            "nuvio"
        } else {
            id
        };
        self.get(lookup)
            .map(|p| p.kind() == ProviderKind::HostRequired)
            .unwrap_or(true)
    }

    pub fn list_builtin_ids(&self) -> Vec<String> {
        self.providers.iter().map(|p| p.id().to_string()).collect()
    }
}
