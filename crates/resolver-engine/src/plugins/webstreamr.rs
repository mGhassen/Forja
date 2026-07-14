use std::collections::HashMap;
use std::time::Instant;

use serde_json::{json, Value};
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
        let is_tv = request.media_type == "tv" || request.media_type == "series";
        let config = webstreamr_config_value(&request.settings);
        let mut req = json!({
            "media_type": if is_tv { "series" } else { "movie" },
            "config": config,
            "enabled_sources": [],
        });
        if !request.imdb_id.trim().is_empty() {
            req["imdb_id"] = Value::String(request.imdb_id.clone());
        }
        if request.tmdb_id > 0 {
            req["tmdb_id"] = json!(request.tmdb_id);
        }
        let title = request.title.trim();
        if !title.is_empty() {
            req["title"] = Value::String(title.to_string());
        }
        if let Some(year) = request.year.filter(|y| *y > 0) {
            req["year"] = json!(year);
        }
        if is_tv {
            req["season"] = json!(if request.season < 1 {
                1
            } else {
                request.season
            });
            req["episode"] = json!(if request.episode < 1 {
                1
            } else {
                request.episode
            });
        }
        let token = request.settings.webstreamr_tmdb_access_token.trim();
        if !token.is_empty() {
            req["tmdb_access_token"] = Value::String(token.to_string());
        }

        let started = Instant::now();
        let raw = webstreamr::get_streams_json(&req.to_string());
        if ctx.is_cancelled() {
            return Err(ProviderError::Cancelled);
        }
        let streams: Vec<Value> = match serde_json::from_str(&raw) {
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
            let url = playable_url(item);
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
            let mut source = from_legacy(&url, title, "hls", headers, self.id(), idx as u8);
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

fn webstreamr_config_value(settings: &crate::request::ResolveSettings) -> Value {
    if settings.webstreamr_config.is_empty() {
        // Empty request → crate default (all countries). Mirrors Dart
        // WebStreamrSettings when prefs are unset.
        return Value::Object(
            webstreamr::config::default_config()
                .into_iter()
                .map(|(k, v)| (k, Value::String(v)))
                .collect(),
        );
    }
    Value::Object(
        settings
            .webstreamr_config
            .iter()
            .map(|(k, v)| (k.clone(), Value::String(v.clone())))
            .collect(),
    )
}

/// Match [WebStreamrService.resolveStreamUrl]: direct, external, or YouTube.
fn playable_url(item: &Value) -> String {
    if let Some(url) = item
        .get("url")
        .or_else(|| item.get("streamUrl"))
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
    {
        return url.to_string();
    }
    if let Some(external) = item
        .get("externalUrl")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
    {
        return external.to_string();
    }
    if let Some(yt) = item
        .get("ytId")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
    {
        return format!("https://www.youtube.com/watch?v={yt}");
    }
    String::new()
}

#[cfg(test)]
mod tests {
    use super::{playable_url, webstreamr_config_value};
    use serde_json::{json, Value};

    #[test]
    fn request_shape_matches_streams_request() {
        let req = json!({
            "imdb_id": "tt11198330",
            "tmdb_id": 94997,
            "media_type": "series",
            "season": 1,
            "episode": 1,
            "title": "House of the Dragon",
            "year": 2022,
            "config": { "multi": "on", "de": "on", "en": "on" },
            "enabled_sources": [],
        });
        let _: webstreamr::resolver::StreamsRequest =
            serde_json::from_value(req).expect("StreamsRequest parse");
    }

    #[test]
    fn webstreamr_config_value_empty_uses_default_countries() {
        let settings = crate::request::ResolveSettings::default();
        let v = webstreamr_config_value(&settings);
        let obj = v.as_object().expect("object");
        assert_eq!(obj.get("de").and_then(|x: &Value| x.as_str()), Some("on"));
        assert_eq!(
            obj.get("multi").and_then(|x: &Value| x.as_str()),
            Some("on")
        );
    }

    #[test]
    fn webstreamr_config_value_respects_explicit_map() {
        let mut settings = crate::request::ResolveSettings::default();
        settings.webstreamr_config.insert("de".into(), "on".into());
        let v = webstreamr_config_value(&settings);
        let obj = v.as_object().expect("object");
        assert_eq!(obj.len(), 1);
        assert_eq!(obj.get("de").and_then(|x: &Value| x.as_str()), Some("on"));
        assert!(obj.get("en").is_none());
    }

    #[test]
    fn playable_url_prefers_direct_then_external_then_youtube() {
        assert_eq!(
            playable_url(&json!({"url": "https://cdn.example/a.m3u8"})),
            "https://cdn.example/a.m3u8"
        );
        assert_eq!(
            playable_url(&json!({"externalUrl": "https://host.example/x"})),
            "https://host.example/x"
        );
        assert_eq!(
            playable_url(&json!({"ytId": "abc123"})),
            "https://www.youtube.com/watch?v=abc123"
        );
        assert_eq!(playable_url(&json!({"name": "none"})), "");
    }
}
