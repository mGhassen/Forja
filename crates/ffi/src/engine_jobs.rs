use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};

use scrapers::search_all;
use stremio_core::{fetch_get, fetch_get_with_headers, fetch_post_with_headers};
use utils::engine_cancel::CancellationToken;

use crate::RUNTIME;

static NEXT_JOB_ID: AtomicU64 = AtomicU64::new(1);

enum JobOutcome {
    Pending,
    Done(String),
}

struct JobStore {
    outcomes: HashMap<u64, JobOutcome>,
    tokens: HashMap<u64, CancellationToken>,
}

static JOBS: LazyLock<Mutex<JobStore>> =
    LazyLock::new(|| Mutex::new(JobStore { outcomes: HashMap::new(), tokens: HashMap::new() }));

#[repr(u32)]
#[derive(Clone, Copy, Debug)]
pub enum JobKind {
    WebstreamrGetStreams = 1,
    StremioHttpGet = 2,
    ResolveVidsrcEmbed = 3,
    SearchTorrents = 4,
    HttpGet = 5,
    HttpPost = 6,
    IptvProbeStream = 7,
    TorrentStream = 8,
}

pub fn submit(kind: u32, payload_json: String) -> u64 {
    let job_id = NEXT_JOB_ID.fetch_add(1, Ordering::SeqCst);
    let token = utils::engine_cancel::new_job_token();

    {
        let mut store = JOBS.lock().unwrap();
        store.outcomes.insert(job_id, JobOutcome::Pending);
        store.tokens.insert(job_id, token.clone());
    }

    RUNTIME.spawn(async move {
        utils::engine_cancel::attach_job_token(token.clone());
        let json = run_job_async(kind, &payload_json).await;
        utils::engine_cancel::clear_job_token();

        let mut store = JOBS.lock().unwrap();
        store.tokens.remove(&job_id);
        if matches!(store.outcomes.get(&job_id), Some(JobOutcome::Pending)) {
            store.outcomes.insert(job_id, JobOutcome::Done(json));
        }
    });

    job_id
}

pub fn take_result(job_id: u64) -> Option<String> {
    let mut store = JOBS.lock().unwrap();
    match store.outcomes.remove(&job_id) {
        Some(JobOutcome::Done(s)) => Some(s),
        Some(JobOutcome::Pending) => {
            store.outcomes.insert(job_id, JobOutcome::Pending);
            None
        }
        None => None,
    }
}

pub fn cancel_all() {
    let cancelled =
        serde_json::json!({ "error": utils::engine_cancel::cancelled_message() }).to_string();
    let mut store = JOBS.lock().unwrap();
    for (_, token) in store.tokens.drain() {
        token.cancel();
    }
    for outcome in store.outcomes.values_mut() {
        if matches!(outcome, JobOutcome::Pending) {
            *outcome = JobOutcome::Done(cancelled.clone());
        }
    }
    drop(store);
    utils::engine_cancel::request();
}

async fn run_job_async(kind: u32, payload_json: &str) -> String {
    match run_job_inner(kind, payload_json).await {
        Ok(s) => s,
        Err(e) => serde_json::json!({ "error": e }).to_string(),
    }
}

async fn run_job_inner(kind: u32, payload_json: &str) -> Result<String, String> {
    match kind {
        k if k == JobKind::WebstreamrGetStreams as u32 => {
            let req: RequestJsonPayload =
                serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let request_json = req.request_json;
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                Ok(webstreamr::get_streams_json(&request_json))
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::StremioHttpGet as u32 => {
            let req: StremioHttpReq = serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                match fetch_get(&req.url, req.timeout_secs) {
                    Ok(resp) => serde_json::to_string(&resp).map_err(|e| e.to_string()),
                    Err(e) => Ok(serde_json::json!({ "error": e }).to_string()),
                }
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::ResolveVidsrcEmbed as u32 => {
            let req: RequestJsonPayload =
                serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let request_json = req.request_json;
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                Ok(webstreamr::resolve_vidsrc_embed_json(&request_json))
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::SearchTorrents as u32 => {
            let req: SearchReq = serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            utils::engine_cancel::with_cancel(async { Ok(search_all(&req.query).await) }).await
                .and_then(|results| serde_json::to_string(&results).map_err(|e| e.to_string()))
        }
        k if k == JobKind::HttpGet as u32 => {
            let req: HttpReq = serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let headers: std::collections::HashMap<String, String> =
                serde_json::from_str(&req.headers_json).unwrap_or_default();
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                match fetch_get_with_headers(&req.url, req.timeout_secs, &headers) {
                    Ok(resp) => serde_json::to_string(&resp).map_err(|e| e.to_string()),
                    Err(e) => Ok(serde_json::json!({ "error": e }).to_string()),
                }
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::HttpPost as u32 => {
            let req: HttpPostReq = serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let headers: std::collections::HashMap<String, String> =
                serde_json::from_str(&req.headers_json).unwrap_or_default();
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                match fetch_post_with_headers(&req.url, req.timeout_secs, &headers, &req.body) {
                    Ok(resp) => serde_json::to_string(&resp).map_err(|e| e.to_string()),
                    Err(e) => Ok(serde_json::json!({ "error": e }).to_string()),
                }
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::IptvProbeStream as u32 => {
            let req: ProbeReq = serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                Ok(iptv_core::stream_probe::probe_stream_alive_json(
                    &req.url,
                    req.timeout_secs,
                ))
            })
            .await
            .map_err(|e| e.to_string())?
        }
        k if k == JobKind::TorrentStream as u32 => {
            let req: TorrentStreamReq =
                serde_json::from_str(payload_json).map_err(|e| e.to_string())?;
            let token = utils::engine_cancel::cancellation_token();
            tokio::task::spawn_blocking(move || {
                utils::engine_cancel::attach_job_token(token);
                Ok(crate::engine_torrent::torrent_stream_json(
                    req.magnet,
                    req.season,
                    req.episode,
                    req.file_idx,
                ))
            })
            .await
            .map_err(|e| e.to_string())?
        }
        _ => Err(format!("unknown job kind {kind}")),
    }
}

#[derive(serde::Deserialize)]
struct RequestJsonPayload {
    #[serde(rename = "requestJson")]
    request_json: String,
}

#[derive(serde::Deserialize)]
struct StremioHttpReq {
    url: String,
    timeout_secs: u64,
}

#[derive(serde::Deserialize)]
struct SearchReq {
    query: String,
}

#[derive(serde::Deserialize)]
struct HttpReq {
    url: String,
    timeout_secs: u64,
    headers_json: String,
}

#[derive(serde::Deserialize)]
struct HttpPostReq {
    url: String,
    timeout_secs: u64,
    headers_json: String,
    body: String,
}

#[derive(serde::Deserialize)]
struct ProbeReq {
    url: String,
    timeout_secs: u64,
}

#[derive(serde::Deserialize)]
struct TorrentStreamReq {
    magnet: String,
    season: i32,
    episode: i32,
    file_idx: i32,
}
