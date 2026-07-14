use std::collections::HashMap;

#[derive(Clone, Default)]
pub struct HeaderManager {
    defaults: HashMap<String, HashMap<String, String>>,
}

impl HeaderManager {
    pub fn new() -> Self {
        let mut defaults = HashMap::new();
        defaults.insert(
            "videasy".into(),
            HashMap::from([
                ("User-Agent".into(), "Mozilla/5.0".into()),
                ("Accept".into(), "*/*".into()),
            ]),
        );
        defaults.insert(
            "vidsrc".into(),
            HashMap::from([
                ("User-Agent".into(), "Mozilla/5.0".into()),
                ("Referer".into(), "https://vsembed.su/".into()),
            ]),
        );
        Self { defaults }
    }

    pub fn merge(
        &self,
        provider_id: &str,
        extra: HashMap<String, String>,
    ) -> HashMap<String, String> {
        let mut out = self.defaults.get(provider_id).cloned().unwrap_or_default();
        for (k, v) in extra {
            if !v.is_empty() {
                out.insert(k, v);
            }
        }
        out
    }

    pub fn for_embed(&self, provider_id: &str, embed_url: &str) -> HashMap<String, String> {
        let mut h = self.merge(provider_id, HashMap::new());
        if let Ok(origin) = extract_origin(embed_url) {
            h.insert("Referer".into(), embed_url.to_string());
            h.insert("Origin".into(), origin);
        }
        h
    }
}

fn extract_origin(url: &str) -> Result<String, ()> {
    let after_scheme = url.split("://").nth(1).ok_or(())?;
    let host = after_scheme.split('/').next().ok_or(())?;
    let scheme = if url.starts_with("https") {
        "https"
    } else {
        "http"
    };
    Ok(format!("{scheme}://{host}"))
}
