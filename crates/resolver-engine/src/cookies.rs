use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[derive(Clone, Default)]
pub struct CookieJar {
    inner: Arc<Mutex<HashMap<String, HashMap<String, String>>>>,
}

impl CookieJar {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set(&self, domain: &str, name: &str, value: &str) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        g.entry(domain.to_string())
            .or_default()
            .insert(name.to_string(), value.to_string());
    }

    pub fn get_header(&self, domain: &str) -> Option<String> {
        let g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        let cookies = g.get(domain)?;
        if cookies.is_empty() {
            return None;
        }
        Some(
            cookies
                .iter()
                .map(|(k, v)| format!("{k}={v}"))
                .collect::<Vec<_>>()
                .join("; "),
        )
    }

    pub fn snapshot(&self) -> HashMap<String, HashMap<String, String>> {
        self.inner.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    pub fn restore(&self, snapshot: HashMap<String, HashMap<String, String>>) {
        let mut g = self.inner.lock().unwrap_or_else(|e| e.into_inner());
        *g = snapshot;
    }
}
