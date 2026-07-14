use std::time::Instant;

use serde_json::json;
use stream::from_legacy;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::StreamResult;

pub struct VidsrcProvider;

impl Provider for VidsrcProvider {
    fn id(&self) -> &str {
        "vidsrc"
    }

    fn kind(&self) -> ProviderKind {
        ProviderKind::RustNative
    }

    fn resolve(
        &self,
        request: &StreamRequest,
        ctx: &ResolverContext,
    ) -> Result<StreamResult, ProviderError> {
        if ctx.is_cancelled() {
            return Err(ProviderError::Cancelled);
        }
        let is_tv = request.media_type == "tv";
        // Native extractor builds vsembed.su URLs itself — do not use
        // stream::build_*_url (template-only; returns None for "vidsrc").
        let req = json!({
            "tmdb_id": request.tmdb_id,
            "is_movie": !is_tv,
            "season": if is_tv { Some(request.season) } else { None::<i32> },
            "episode": if is_tv { Some(request.episode) } else { None::<i32> },
        });
        let started = Instant::now();
        let raw = webstreamr::resolve_vidsrc_embed_json(&req.to_string());
        if ctx.is_cancelled() {
            return Err(ProviderError::Cancelled);
        }
        let parsed: serde_json::Value =
            serde_json::from_str(&raw).map_err(|_| ProviderError::NoStreams)?;
        if parsed.get("error").is_some() {
            return Err(ProviderError::NoStreams);
        }
        let url = parsed.get("url").and_then(|v| v.as_str()).unwrap_or("");
        if url.is_empty() {
            return Err(ProviderError::NoStreams);
        }
        let mut headers = std::collections::HashMap::new();
        if let Some(h) = parsed.get("headers").and_then(|v| v.as_object()) {
            for (k, v) in h {
                if let Some(s) = v.as_str() {
                    headers.insert(k.clone(), s.to_string());
                }
            }
        }
        let source = from_legacy(url, "Vidsrc", "hls", headers, self.id(), 0);
        let mut source = source;
        source.headers = ctx.merge_headers(self.id(), source.headers);
        Ok(StreamResult {
            provider_id: self.id().to_string(),
            sources: vec![source],
            latency_ms: started.elapsed().as_millis() as u32,
        })
    }
}
