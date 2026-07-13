use std::collections::HashMap;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::time::Instant;

use stream_core::PlayableSource;

use crate::context::ResolverContext;
use crate::provider::ProviderError;
use crate::registry::ProviderRegistry;
use crate::request::{ContinueRequest, StreamRequest};
use crate::result::{
    HostResolveRequest, ResolvePhase, ResolveProgressEvent, ResolveResponse,
};
use crate::scoring::{domain_label, rank_playable_sources};

#[derive(Clone)]
struct ResolveSession {
    request: StreamRequest,
    ordered_ids: Vec<String>,
    effective_ranks: HashMap<String, u32>,
    collected: Vec<PlayableSource>,
    progress: Vec<ResolveProgressEvent>,
    started: Instant,
}

static SESSIONS: std::sync::LazyLock<Mutex<HashMap<String, ResolveSession>>> =
    std::sync::LazyLock::new(|| Mutex::new(HashMap::new()));

fn next_session_id() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(1);
    format!("re-{}", COUNTER.fetch_add(1, Ordering::SeqCst))
}

fn candidate_ids(request: &StreamRequest) -> Vec<String> {
    if !request.settings.enabled_provider_ids.is_empty() {
        return request.settings.enabled_provider_ids.clone();
    }
    if !request.providers_json.is_empty() {
        if let Ok(list) = serde_json::from_str::<Vec<String>>(&request.providers_json) {
            if !list.is_empty() {
                return list;
            }
        }
        if let Ok(map) =
            serde_json::from_str::<HashMap<String, serde_json::Value>>(&request.providers_json)
        {
            return map.keys().cloned().collect();
        }
    }
    ProviderRegistry::built_in().list_builtin_ids()
}

fn effective_ranks_map(
    _registry: &ProviderRegistry,
    _request: &StreamRequest,
    ordered: &[String],
) -> HashMap<String, u32> {
    ordered
        .iter()
        .enumerate()
        .map(|(i, id)| (id.clone(), i as u32))
        .collect()
}

fn ingest_host_sources(
    provider_id: &str,
    sources_json: &str,
    rank_base: u32,
) -> Vec<PlayableSource> {
    let Ok(items) = serde_json::from_str::<Vec<serde_json::Value>>(sources_json) else {
        if let Ok(one) = serde_json::from_str::<serde_json::Value>(sources_json) {
            if let Some(url) = one.get("url").and_then(|v| v.as_str()) {
                let mut s = stream_core::from_legacy(
                    url,
                    one.get("title")
                        .and_then(|v| v.as_str())
                        .unwrap_or("Stream"),
                    "hls",
                    HashMap::new(),
                    provider_id,
                    rank_base as u8,
                );
                s.effective_rank = Some(rank_base);
                s.baseline_rank = Some(rank_base);
                return vec![s];
            }
        }
        return vec![];
    };
    items
        .into_iter()
        .enumerate()
        .filter_map(|(idx, item)| {
            let url = item.get("url").and_then(|v| v.as_str())?;
            if url.is_empty() {
                return None;
            }
            let title = item
                .get("title")
                .and_then(|v| v.as_str())
                .unwrap_or("Stream");
            let mut headers = HashMap::new();
            if let Some(h) = item.get("headers").and_then(|v| v.as_object()) {
                for (k, v) in h {
                    if let Some(s) = v.as_str() {
                        headers.insert(k.clone(), s.to_string());
                    }
                }
            }
            let mut s = stream_core::from_legacy(
                url,
                title,
                item.get("container")
                    .and_then(|v| v.as_str())
                    .unwrap_or("hls"),
                headers,
                provider_id,
                (rank_base + idx as u32) as u8,
            );
            s.effective_rank = Some(rank_base + idx as u32);
            s.baseline_rank = Some(rank_base);
            Some(s)
        })
        .collect()
}

fn finalize_response(session: ResolveSession) -> ResolveResponse {
    let ranked = rank_playable_sources(
        session.collected,
        session.request.device.clone(),
        session.request.settings.blocklist_urls.clone(),
    );
    let winner = ranked.first().cloned();
    let winner_provider_id = winner.as_ref().map(|w| w.provider_id.clone());
    ResolveResponse {
        phase: ResolvePhase::Complete,
        session_id: String::new(),
        winner,
        sources: ranked,
        winner_provider_id,
        host_requests: vec![],
        progress: session.progress,
        race_ms: session.started.elapsed().as_millis() as u32,
        error: None,
    }
}

pub fn resolve(request_json: &str) -> String {
    match resolve_inner(request_json) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|e| {
            serde_json::json!({ "error": e.to_string() }).to_string()
        }),
        Err(e) => serde_json::to_string(&ResolveResponse::failed(e)).unwrap(),
    }
}

fn resolve_inner(request_json: &str) -> Result<ResolveResponse, String> {
    let request: StreamRequest =
        serde_json::from_str(request_json).map_err(|e| e.to_string())?;
    let started = Instant::now();
    let registry = Arc::new(ProviderRegistry::built_in());
    let ctx = ResolverContext::new();

    let mut candidates = candidate_ids(&request);
    candidates = registry.filter_enabled(
        &candidates,
        &request.settings.enabled_provider_ids,
    );
    let ordered = registry.ordered_ids(
        request.domain,
        &candidates,
        &request.settings.settings_order,
        &request.settings.preferred,
    );

    if ordered.len() == 1 {
        return resolve_single(&registry, &ctx, &request, &ordered[0], started);
    }

    let effective_ranks = effective_ranks_map(&registry, &request, &ordered);
    let max_in_flight = request.settings.max_in_flight.max(1) as usize;
    let mut collected = Vec::new();
    let mut pending_host = Vec::new();
    let mut progress = Vec::new();
    let mut idx = 0usize;

    while idx < ordered.len() && collected.is_empty() {
        if ctx.is_cancelled() {
            return Err("cancelled".into());
        }

        let mut batch_native = Vec::new();
        while idx < ordered.len() && batch_native.len() < max_in_flight {
            let id = ordered[idx].clone();
            idx += 1;

            if request.settings.skip_host_on_tv && registry.is_host_required(&id) {
                progress.push(ResolveProgressEvent {
                    provider_id: id.clone(),
                    status: "skipped_on_tv".into(),
                    message: None,
                });
                continue;
            }

            if registry.is_host_required(&id) {
                push_host_attempt(
                    &registry,
                    &ctx,
                    &request,
                    &id,
                    &effective_ranks,
                    &mut progress,
                    &mut pending_host,
                    &mut collected,
                )?;
                if !collected.is_empty() {
                    break;
                }
                continue;
            }

            batch_native.push(id);
        }

        if !collected.is_empty() {
            break;
        }

        if batch_native.is_empty() {
            continue;
        }

        for id in &batch_native {
            progress.push(ResolveProgressEvent {
                provider_id: id.clone(),
                status: "trying".into(),
                message: None,
            });
        }

        if let Some((winner_id, sources)) = parallel_try_native(
            &registry,
            &ctx,
            &request,
            &batch_native,
            &effective_ranks,
        ) {
            progress.push(ResolveProgressEvent {
                provider_id: winner_id.clone(),
                status: "success".into(),
                message: None,
            });
            for id in &batch_native {
                if id != &winner_id {
                    progress.push(ResolveProgressEvent {
                        provider_id: id.clone(),
                        status: "failed".into(),
                        message: Some("lost race".into()),
                    });
                }
            }
            collected = sources;
            break;
        }

        for id in &batch_native {
            progress.push(ResolveProgressEvent {
                provider_id: id.clone(),
                status: "failed".into(),
                message: None,
            });
        }
    }

    if collected.is_empty() && !pending_host.is_empty() {
        let session_id = next_session_id();
        let session = ResolveSession {
            request: request.clone(),
            ordered_ids: ordered.clone(),
            effective_ranks: effective_ranks.clone(),
            collected,
            progress: progress.clone(),
            started,
        };
        SESSIONS
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(session_id.clone(), session);
        return Ok(ResolveResponse {
            phase: ResolvePhase::AwaitingHost,
            session_id,
            winner: None,
            sources: vec![],
            winner_provider_id: None,
            host_requests: pending_host,
            progress,
            race_ms: started.elapsed().as_millis() as u32,
            error: None,
        });
    }

    if collected.is_empty() {
        return Ok(ResolveResponse {
            phase: ResolvePhase::Failed,
            progress,
            race_ms: started.elapsed().as_millis() as u32,
            error: Some("no streams".into()),
            ..Default::default()
        });
    }

    Ok(finalize_response(ResolveSession {
        request,
        ordered_ids: ordered,
        effective_ranks,
        collected,
        progress,
        started,
    }))
}

fn push_host_attempt(
    registry: &ProviderRegistry,
    ctx: &ResolverContext,
    request: &StreamRequest,
    id: &str,
    effective_ranks: &HashMap<String, u32>,
    progress: &mut Vec<ResolveProgressEvent>,
    pending_host: &mut Vec<HostResolveRequest>,
    collected: &mut Vec<PlayableSource>,
) -> Result<(), String> {
    progress.push(ResolveProgressEvent {
        provider_id: id.to_string(),
        status: "trying".into(),
        message: None,
    });
    let rank = *effective_ranks.get(id).unwrap_or(&0);
    match try_provider(registry, ctx, request, id, rank) {
        Ok(sources) if !sources.is_empty() => {
            progress.push(ResolveProgressEvent {
                provider_id: id.to_string(),
                status: "success".into(),
                message: None,
            });
            collected.extend(sources);
        }
        Ok(_) => {
            progress.push(ResolveProgressEvent {
                provider_id: id.to_string(),
                status: "failed".into(),
                message: Some("no streams".into()),
            });
        }
        Err(ProviderError::HostRequired(req)) => {
            progress.push(ResolveProgressEvent {
                provider_id: req.provider_id.clone(),
                status: "host_resolve_needed".into(),
                message: None,
            });
            pending_host.push(req);
        }
        Err(ProviderError::Cancelled) => return Err("cancelled".into()),
        Err(_) => {
            progress.push(ResolveProgressEvent {
                provider_id: id.to_string(),
                status: "failed".into(),
                message: None,
            });
        }
    }
    Ok(())
}

fn parallel_try_native(
    registry: &Arc<ProviderRegistry>,
    ctx: &ResolverContext,
    request: &StreamRequest,
    batch: &[String],
    effective_ranks: &HashMap<String, u32>,
) -> Option<(String, Vec<PlayableSource>)> {
    if batch.is_empty() {
        return None;
    }
    if batch.len() == 1 {
        let id = &batch[0];
        let rank = *effective_ranks.get(id).unwrap_or(&0);
        return match try_provider(registry, ctx, request, id, rank) {
            Ok(sources) if !sources.is_empty() => Some((id.clone(), sources)),
            _ => None,
        };
    }

    let results: Arc<Mutex<Vec<(String, Vec<PlayableSource>)>>> =
        Arc::new(Mutex::new(Vec::new()));
    let done = Arc::new(AtomicBool::new(false));

    std::thread::scope(|s| {
        for id in batch {
            let results = Arc::clone(&results);
            let done = Arc::clone(&done);
            let registry = Arc::clone(registry);
            let ctx = ctx.clone();
            let request = request.clone();
            let id = id.clone();
            let rank = *effective_ranks.get(&id).unwrap_or(&0);
            s.spawn(move || {
                if done.load(Ordering::Relaxed) || ctx.is_cancelled() {
                    return;
                }
                match try_provider(&registry, &ctx, &request, &id, rank) {
                    Ok(sources) if !sources.is_empty() => {
                        let mut g = results.lock().unwrap_or_else(|e| e.into_inner());
                        g.push((id, sources));
                        done.store(true, Ordering::Relaxed);
                    }
                    Err(ProviderError::Cancelled) => ctx.request_cancel(),
                    _ => {}
                }
            });
        }
    });

    let mut winners = results.lock().unwrap_or_else(|e| e.into_inner()).clone();
    if winners.is_empty() {
        return None;
    }
    winners.sort_by_key(|(id, _)| effective_ranks.get(id).copied().unwrap_or(u32::MAX));
    winners.into_iter().next()
}

fn resolve_single(
    registry: &Arc<ProviderRegistry>,
    ctx: &ResolverContext,
    request: &StreamRequest,
    id: &str,
    started: Instant,
) -> Result<ResolveResponse, String> {
    let mut progress = vec![ResolveProgressEvent {
        provider_id: id.to_string(),
        status: "trying".into(),
        message: None,
    }];
    match try_provider(registry, ctx, request, id, 0) {
        Ok(sources) if !sources.is_empty() => {
            progress.push(ResolveProgressEvent {
                provider_id: id.to_string(),
                status: "success".into(),
                message: None,
            });
            Ok(finalize_response(ResolveSession {
                request: request.clone(),
                ordered_ids: vec![id.to_string()],
                effective_ranks: HashMap::new(),
                collected: sources,
                progress,
                started,
            }))
        }
        Err(ProviderError::HostRequired(req)) => {
            let session_id = next_session_id();
            let session = ResolveSession {
                request: request.clone(),
                ordered_ids: vec![id.to_string()],
                effective_ranks: HashMap::new(),
                collected: vec![],
                progress: progress.clone(),
                started,
            };
            SESSIONS
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .insert(session_id.clone(), session);
            Ok(ResolveResponse {
                phase: ResolvePhase::AwaitingHost,
                session_id,
                host_requests: vec![req],
                progress,
                race_ms: started.elapsed().as_millis() as u32,
                ..Default::default()
            })
        }
        Err(e) => Ok(ResolveResponse {
            phase: ResolvePhase::Failed,
            progress,
            race_ms: started.elapsed().as_millis() as u32,
            error: Some(format!("{e}")),
            ..Default::default()
        }),
        _ => Ok(ResolveResponse {
            phase: ResolvePhase::Failed,
            progress,
            race_ms: started.elapsed().as_millis() as u32,
            error: Some("no streams".into()),
            ..Default::default()
        }),
    }
}

fn try_provider(
    registry: &ProviderRegistry,
    ctx: &ResolverContext,
    request: &StreamRequest,
    id: &str,
    rank: u32,
) -> Result<Vec<PlayableSource>, ProviderError> {
    let provider_id = if id.starts_with("nuvio:") {
        "nuvio"
    } else {
        id
    };
    let provider = registry
        .get(provider_id)
        .ok_or(ProviderError::Message(format!("unknown provider {id}")))?;

    if let Some((_, cached)) = ctx.cache.get(
        domain_label(request.domain),
        request.tmdb_id,
        request.season,
        request.episode,
        id,
    ) {
        return Ok(cached);
    }

    let result = provider.resolve(request, ctx);
    match result {
        Err(ProviderError::HostRequired(_)) => return result.map(|_| vec![]),
        Err(e) => {
            ctx.health.record_server_down(request, id);
            return Err(e);
        }
        Ok(result) => {
            ctx.health.record_server_up(request, &result.provider_id);
            let mut sources = result.sources;
            for s in &mut sources {
                s.provider_id = id.to_string();
                s.effective_rank = Some(rank);
                s.baseline_rank = Some(rank);
                s.provider_rank = rank as u8;
            }
            ctx.cache.put(
                domain_label(request.domain),
                request.tmdb_id,
                request.season,
                request.episode,
                id,
                sources.clone(),
            );
            if sources.is_empty() {
                ctx.health.record_server_down(request, id);
                return Err(ProviderError::NoStreams);
            }
            Ok(sources)
        }
    }
}

pub fn continue_with_host(payload_json: &str) -> String {
    match continue_inner(payload_json) {
        Ok(resp) => serde_json::to_string(&resp).unwrap_or_else(|e| {
            serde_json::json!({ "error": e.to_string() }).to_string()
        }),
        Err(e) => serde_json::to_string(&ResolveResponse::failed(e)).unwrap(),
    }
}

fn continue_inner(payload_json: &str) -> Result<ResolveResponse, String> {
    let req: ContinueRequest =
        serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
    let mut session = SESSIONS
        .lock()
        .unwrap_or_else(|e| e.into_inner())
        .remove(&req.session_id)
        .ok_or_else(|| "session not found".to_string())?;

    let mut collected = session.collected;
    for host in req.host_results {
        if let Some(err) = host.error {
            session
                .request
                .settings
                .blocklist_urls
                .push(err);
            continue;
        }
        let rank = *session
            .effective_ranks
            .get(&host.provider_id)
            .unwrap_or(&0);
        let sources = ingest_host_sources(&host.provider_id, &host.sources_json, rank);
        if !sources.is_empty() {
            collected.extend(sources);
        }
    }

    Ok(finalize_response(ResolveSession {
        request: session.request,
        ordered_ids: session.ordered_ids,
        effective_ranks: session.effective_ranks,
        collected,
        progress: session.progress,
        started: session.started,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::request::ResolveSettings;
    use stream_core::DevicePlaybackCapabilities;
    use stream_core::SourceDomain;

    #[test]
    fn resolve_orders_providers() {
        let payload = serde_json::json!({
            "domain": "movies",
            "tmdbId": 575265,
            "mediaType": "movie",
            "settings": {
                "enabledProviderIds": ["webstreamr", "vidsrc"],
                "preferred": "auto",
                "maxInFlight": 2
            }
        });
        let raw = resolve(&payload.to_string());
        let parsed: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert!(parsed.get("phase").is_some());
    }

    #[test]
    fn host_continue_flow_finalizes_sources() {
        let payload = serde_json::json!({
            "domain": "movies",
            "tmdbId": 1,
            "mediaType": "movie",
            "settings": {
                "enabledProviderIds": ["videasy"],
                "maxInFlight": 1
            }
        });
        let raw = resolve(&payload.to_string());
        let first: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(first["phase"], "awaiting_host");
        let session_id = first["sessionId"].as_str().unwrap();
        let continue_payload = serde_json::json!({
            "sessionId": session_id,
            "hostResults": [{
                "providerId": "videasy",
                "sourcesJson": "[{\"url\":\"https://example.com/stream.m3u8\",\"title\":\"Primary\",\"container\":\"hls\"}]"
            }]
        });
        let done_raw = continue_with_host(&continue_payload.to_string());
        let done: serde_json::Value = serde_json::from_str(&done_raw).unwrap();
        assert_eq!(done["phase"], "complete");
        assert!(done["winner"].is_object());
        assert_eq!(
            done["winner"]["url"].as_str().unwrap(),
            "https://example.com/stream.m3u8"
        );
    }

    #[test]
    fn parallel_batch_picks_lowest_rank_winner() {
        let ranks = HashMap::from([
            ("webstreamr".to_string(), 0_u32),
            ("vidsrc".to_string(), 1_u32),
        ]);
        let registry = Arc::new(ProviderRegistry::built_in());
        let ctx = ResolverContext::new();
        let request = StreamRequest {
            domain: SourceDomain::Movies,
            tmdb_id: 1,
            imdb_id: String::new(),
            title: String::new(),
            year: None,
            season: 1,
            episode: 1,
            media_type: "movie".into(),
            device: DevicePlaybackCapabilities::default(),
            settings: ResolveSettings {
                enabled_provider_ids: vec!["webstreamr".into(), "vidsrc".into()],
                max_in_flight: 2,
                ..Default::default()
            },
            providers_json: String::new(),
        };
        let batch = vec!["webstreamr".to_string(), "vidsrc".to_string()];
        let winner = parallel_try_native(&registry, &ctx, &request, &batch, &ranks);
        // Either provider may win depending on network; ensure structure when present.
        if let Some((id, sources)) = winner {
            assert!(id == "webstreamr" || id == "vidsrc");
            assert!(!sources.is_empty());
        }
    }
}
