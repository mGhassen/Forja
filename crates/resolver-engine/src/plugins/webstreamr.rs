use std::collections::HashMap;
use std::time::Instant;

use serde_json::json;
use stream_core::from_legacy;

use crate::context::ResolverContext;
use crate::provider::{Provider, ProviderError, ProviderKind};
use crate::request::StreamRequest;
use crate::result::StreamResult;

pub struct WebstreamrProvider;

impl Provider for WebstreamrProvider {
    fn id(&self) -> &str {
        "webstreamr"
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
        let req = if is_tv {
            json!({
                "imdbId": request.imdb_id,
                "tmdbId": request.tmdb_id,
                "title": request.title,
                "year": request.year,
                "isMovie": false,
                "season": request.season,
                "episode": request.episode,
            })
        } else {
            json!({
                "imdbId": request.imdb_id,
                "tmdbId": request.tmdb_id,
                "title": request.title,
                "year": request.year,
                "isMovie": true,
            })
        };
        let started = Instant::now();
        let raw = webstreamr::get_streams_json(&req.to_string());
        if ctx.is_cancelled() {
            return Err(ProviderError::Cancelled);
        }
        let streams: Vec<serde_json::Value> = match serde_json::from_str(&raw) {
            Ok(v) => v,
            Err(_) => {
                if raw.contains("\"error\"") {
                    return Err(ProviderError::NoStreams);
                }
                return Err(ProviderError::Message(raw));
            }
        };
        let mut sources = Vec::new();
        for (idx, item) in streams.iter().enumerate() {
            let url = item
                .get("url")
                .or_else(|| item.get("streamUrl"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if url.is_empty() {
                continue;
            }
            let title = item
                .get("title")
                .or_else(|| item.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("Stream");
            let mut headers = HashMap::new();
            if let Some(hints) = item.get("behaviorHints") {
                if let Some(proxy) = hints.get("proxyHeaders") {
                    if let Some(req_headers) = proxy.get("request") {
                        if let Some(map) = req_headers.as_object() {
                            for (k, v) in map {
                                if let Some(s) = v.as_str() {
                                    headers.insert(k.clone(), s.to_string());
                                }
                            }
                        }
                    }
                }
            }
            let mut source = from_legacy(
                url,
                title,
                "hls",
                headers,
                self.id(),
                idx as u8,
            );
            source.headers = ctx.merge_headers(self.id(), source.headers);
            sources.push(source);
        }
        if sources.is_empty() {
            return Err(ProviderError::NoStreams);
        }
        Ok(StreamResult {
            provider_id: self.id().to_string(),
            sources,
            latency_ms: started.elapsed().as_millis() as u32,
        })
    }
}
