use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::cache::ResolveCache;
use crate::cookies::CookieJar;
use crate::headers::HeaderManager;
use crate::health::HealthChecker;
use crate::http::HttpClient;

#[derive(Clone)]
pub struct ResolverContext {
    pub http: HttpClient,
    pub cookies: CookieJar,
    pub headers: HeaderManager,
    pub health: HealthChecker,
    pub cache: ResolveCache,
    cancel: Arc<Mutex<bool>>,
}

impl ResolverContext {
    pub fn new() -> Self {
        Self {
            http: HttpClient::new(),
            cookies: CookieJar::new(),
            headers: HeaderManager::new(),
            health: HealthChecker::new(),
            cache: ResolveCache::new(),
            cancel: Arc::new(Mutex::new(false)),
        }
    }

    pub fn with_cancel_token(cancel: Arc<Mutex<bool>>) -> Self {
        Self {
            http: HttpClient::new(),
            cookies: CookieJar::new(),
            headers: HeaderManager::new(),
            health: HealthChecker::new(),
            cache: ResolveCache::new(),
            cancel,
        }
    }

    pub fn is_cancelled(&self) -> bool {
        *self.cancel.lock().unwrap_or_else(|e| e.into_inner())
    }

    pub fn request_cancel(&self) {
        if let Ok(mut g) = self.cancel.lock() {
            *g = true;
        }
    }

    pub fn merge_headers(
        &self,
        provider_id: &str,
        extra: HashMap<String, String>,
    ) -> HashMap<String, String> {
        self.headers.merge(provider_id, extra)
    }
}

impl Default for ResolverContext {
    fn default() -> Self {
        Self::new()
    }
}
