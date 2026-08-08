use axum::{
    extract::{Extension, Query, State},
    http::StatusCode,
    middleware,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use proxy::ProxyState;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpSocket;
use tokio::sync::oneshot;

/// Invoked after pair / revoke so the host can persist device tokens.
pub type DevicesChangedHook = Arc<dyn Fn(&PairingState) + Send + Sync>;
/// Invoked after LAN torrent history changes so the host can persist.
pub type HistoryChangedHook = Arc<dyn Fn(&TorrentHistory) + Send + Sync>;
use torrent::{torrent_stream_router, TorrentAppState, TorrentEngine};

use crate::auth::{require_bearer_token, require_stream_ticket};
use crate::bind::LanBindMode;
use crate::history::{TorrentHistory, TorrentHistoryEntry};
use crate::mdns::MdnsAnnouncer;
use crate::pairing::{PairRequest, PairResponse, PairingState, RevokeRequest};

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Clone)]
pub struct LanServerState {
    pub pairing: PairingState,
    pub proxy_state: ProxyState,
    pub torrent: Arc<TorrentEngine>,
    pub history: TorrentHistory,
    pub listen_port: Arc<tokio::sync::RwLock<u16>>,
    pub on_devices_changed: Option<DevicesChangedHook>,
    pub on_history_changed: Option<HistoryChangedHook>,
}

pub struct LanServer {
    shutdown: Option<oneshot::Sender<()>>,
    /// Completes when the axum serve task exits (socket released).
    serve_done: Option<oneshot::Receiver<()>>,
    mdns: Option<MdnsAnnouncer>,
    pub state: LanServerState,
}

impl LanServer {
    pub fn new(
        server_id: String,
        proxy_state: ProxyState,
        torrent: Arc<TorrentEngine>,
    ) -> Self {
        Self {
            shutdown: None,
            serve_done: None,
            mdns: None,
            state: LanServerState {
                pairing: PairingState::new(server_id),
                proxy_state,
                torrent,
                history: TorrentHistory::default(),
                listen_port: Arc::new(tokio::sync::RwLock::new(0)),
                on_devices_changed: None,
                on_history_changed: None,
            },
        }
    }

    pub fn set_on_devices_changed(&mut self, hook: DevicesChangedHook) {
        self.state.on_devices_changed = Some(hook);
    }

    pub fn set_on_history_changed(&mut self, hook: HistoryChangedHook) {
        self.state.on_history_changed = Some(hook);
    }

    pub async fn start(
        &mut self,
        bind_mode: LanBindMode,
        preferred_port: u16,
    ) -> Result<u16, String> {
        if self.shutdown.is_some() {
            let port = *self.state.listen_port.read().await;
            if port > 0 {
                return Ok(port);
            }
        }

        // Caller must start the torrent HTTP engine first — do not
        // `TorrentEngine::start_engine` here (nested tokio runtime panic).
        if self.state.torrent.engine_port() == 0 {
            return Err(
                "torrent engine not running — start it before LAN server".into(),
            );
        }

        let app = build_router(self.state.clone());
        let addr = SocketAddr::new(bind_mode.bind_addr(), preferred_port);
        let listener = bind_lan_listener(addr).await?;
        let port = listener.local_addr().map_err(|e| e.to_string())?.port();
        *self.state.listen_port.write().await = port;

        let (tx, rx) = oneshot::channel();
        let (done_tx, done_rx) = oneshot::channel();
        self.shutdown = Some(tx);
        self.serve_done = Some(done_rx);
        tokio::spawn(async move {
            axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = rx.await;
                })
                .await
                .ok();
            let _ = done_tx.send(());
        });

        if bind_mode == LanBindMode::AllInterfaces {
            let server_id = self.state.pairing.server_id();
            // Bonjour often fails under macOS app sandbox; HTTP server must still start.
            match MdnsAnnouncer::announce(&server_id, port, VERSION) {
                Ok(mdns) => self.mdns = Some(mdns),
                Err(e) => {
                    eprintln!(
                        "[lan] mDNS announce failed (server still on :{port}): {e}"
                    );
                }
            }
        }

        self.state.pairing.refresh_code();
        Ok(port)
    }

    /// Signal graceful shutdown and wait until the listen socket is released.
    pub async fn stop(&mut self) {
        if let Some(tx) = self.shutdown.take() {
            let _ = tx.send(());
        }
        self.mdns.take();
        if let Some(done) = self.serve_done.take() {
            let _ = tokio::time::timeout(Duration::from_millis(1500), done).await;
        }
        *self.state.listen_port.write().await = 0;
    }

    pub fn port(&self) -> u16 {
        self.state
            .listen_port
            .try_read()
            .map(|p| *p)
            .unwrap_or(0)
    }

    pub fn pairing_code(&self) -> String {
        self.state
            .pairing
            .current_code()
            .unwrap_or_else(|| self.state.pairing.refresh_code())
    }
}

/// Bind with `SO_REUSEADDR` so a sticky preferred port can reopen after stop
/// without waiting out TIME_WAIT (the old bug that forced a new random port).
async fn bind_lan_listener(addr: SocketAddr) -> Result<tokio::net::TcpListener, String> {
    let socket = if addr.is_ipv4() {
        TcpSocket::new_v4().map_err(|e| e.to_string())?
    } else {
        TcpSocket::new_v6().map_err(|e| e.to_string())?
    };
    socket.set_reuseaddr(true).map_err(|e| e.to_string())?;
    socket.bind(addr).map_err(|e| e.to_string())?;
    socket.listen(128).map_err(|e| e.to_string())
}

fn build_router(state: LanServerState) -> Router {
    let pairing = Arc::new(state.pairing.clone());
    let public = Router::new()
        .route("/health", get(health_handler))
        .route("/pair", post(pair_handler))
        .with_state(state.clone());

    let protected = Router::new()
        .route("/devices", get(devices_handler))
        .route("/revoke", post(revoke_handler))
        .route("/open", post(open_handler))
        .route("/close", post(close_handler))
        .route("/search", get(search_handler))
        .route("/status", get(status_handler))
        .route_layer(middleware::from_fn({
            let pairing = pairing.clone();
            move |req, next| {
                let pairing = pairing.clone();
                async move { require_bearer_token(pairing, req, next).await }
            }
        }))
        .with_state(state.clone());

    let stream_pairing = pairing.clone();
    // proxy_media_router omits /health — axum::merge panics on overlapping routes.
    let mut streams = proxy::proxy_media_router(state.proxy_state.clone());
    if let Some(api) = state.torrent.torrent_api() {
        streams = streams.merge(torrent_stream_router(TorrentAppState { api }));
    }
    streams = streams.route_layer(middleware::from_fn(move |req, next| {
        let pairing = stream_pairing.clone();
        async move { require_stream_ticket(pairing, req, next).await }
    }));

    streams.merge(protected).merge(public)
}

async fn health_handler(State(state): State<LanServerState>) -> impl IntoResponse {
    Json(serde_json::json!({
        "status": "ok",
        "server_id": state.pairing.server_id(),
        "version": VERSION,
        "port": *state.listen_port.read().await,
    }))
}

async fn pair_handler(
    State(state): State<LanServerState>,
    Json(body): Json<PairRequest>,
) -> Result<Json<PairResponse>, (StatusCode, Json<serde_json::Value>)> {
    let token = state
        .pairing
        .pair(&body.code, &body.device_id, body.label)
        .map_err(|e| {
            (
                StatusCode::BAD_REQUEST,
                Json(serde_json::json!({ "error": e })),
            )
        })?;
    notify_devices_changed(&state);
    Ok(Json(PairResponse {
        token,
        server_id: state.pairing.server_id(),
    }))
}

async fn devices_handler(
    State(state): State<LanServerState>,
) -> Json<Vec<crate::pairing::DeviceRecord>> {
    Json(state.pairing.list_devices())
}

async fn revoke_handler(
    State(state): State<LanServerState>,
    Json(body): Json<RevokeRequest>,
) -> impl IntoResponse {
    let ok = state.pairing.revoke_device(&body.device_id);
    if ok {
        notify_devices_changed(&state);
    }
    Json(serde_json::json!({ "ok": ok }))
}

fn notify_devices_changed(state: &LanServerState) {
    if let Some(hook) = &state.on_devices_changed {
        hook(&state.pairing);
    }
}

#[derive(Debug, Deserialize)]
struct OpenRequest {
    kind: String,
    #[serde(default)]
    magnet: Option<String>,
    #[serde(default)]
    season: Option<i32>,
    #[serde(default)]
    episode: Option<i32>,
    #[serde(default)]
    file_idx: Option<i32>,
    #[serde(default)]
    upstream_url: Option<String>,
    #[serde(default)]
    proxy_token: Option<String>,
    #[serde(default)]
    headers: Option<HashMap<String, String>>,
    #[serde(default)]
    host: Option<String>,
}

#[derive(Debug, Serialize)]
struct OpenResponse {
    play_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    headers: Option<HashMap<String, String>>,
}

async fn open_handler(
    State(state): State<LanServerState>,
    Extension(device_token): Extension<String>,
    Json(body): Json<OpenRequest>,
) -> Result<Json<OpenResponse>, (StatusCode, Json<serde_json::Value>)> {
    let port = *state.listen_port.read().await;
    let host = body
        .host
        .filter(|h| !h.is_empty())
        .unwrap_or_else(|| "127.0.0.1".to_string());
    let base = format!("http://{host}:{port}");
    let ticket = state
        .pairing
        .mint_stream_ticket(&device_token)
        .map_err(|e| bad_request(&e))?;

    let response = match body.kind.as_str() {
        "direct" => {
            let url = body
                .upstream_url
                .filter(|u| !u.is_empty())
                .ok_or_else(|| bad_request("upstream_url required for direct"))?;
            OpenResponse {
                play_url: url,
                headers: body.headers,
            }
        }
        "proxy" => {
            let upstream = body
                .upstream_url
                .filter(|u| !u.is_empty())
                .ok_or_else(|| bad_request("upstream_url required for proxy"))?;
            let token = body
                .proxy_token
                .filter(|t| !t.is_empty())
                .unwrap_or_else(|| format!("lan-{}", rand::random::<u32>()));
            state
                .proxy_state
                .routes
                .write()
                .await
                .insert(token.clone(), upstream);
            OpenResponse {
                play_url: append_stream_ticket(&format!("{base}/proxy/{token}"), &ticket),
                headers: body.headers,
            }
        }
        "torrent" => {
            let magnet = body
                .magnet
                .filter(|m| !m.is_empty())
                .ok_or_else(|| bad_request("magnet required for torrent"))?;
            // Must not call `stream_magnet_json` here — that `block_on`s the
            // torrent Runtime from inside the LAN/FFI Tokio worker and panics.
            let parsed = state
                .torrent
                .stream_magnet_on_engine(
                    magnet.clone(),
                    body.season,
                    body.episode,
                    body.file_idx,
                )
                .await
                .map_err(|e| bad_request(&e))?;
            let play_url =
                append_stream_ticket(&rewrite_local_url(&parsed.url, &host, port), &ticket);
            record_torrent_open(
                &state,
                &device_token,
                &magnet,
                Some(parsed.info_hash.as_str()),
                &parsed.url,
            );
            OpenResponse {
                play_url,
                headers: None,
            }
        }
        other => return Err(bad_request(&format!("unknown kind: {other}"))),
    };
    Ok(Json(response))
}

#[derive(Debug, Deserialize)]
struct CloseRequest {
    kind: String,
    #[serde(default)]
    info_hash: Option<String>,
}

/// Stop a LAN-opened torrent when the client leaves the player.
///
/// Requires `info_hash` and only stops when it matches the active swarm —
/// so pushReplacement after a new `/open` does not kill the new download.
async fn close_handler(
    State(state): State<LanServerState>,
    Json(body): Json<CloseRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    match body.kind.as_str() {
        "torrent" => {
            let want = body
                .info_hash
                .as_deref()
                .map(str::trim)
                .filter(|h| !h.is_empty())
                .ok_or_else(|| bad_request("info_hash required for torrent"))?;
            let Some(status) = state.torrent.status() else {
                return Ok(Json(serde_json::json!({ "ok": true, "stopped": false })));
            };
            if !status.info_hash.eq_ignore_ascii_case(want) {
                return Ok(Json(serde_json::json!({ "ok": true, "stopped": false })));
            }
            state.torrent.stop();
            Ok(Json(serde_json::json!({ "ok": true, "stopped": true })))
        }
        other => Err(bad_request(&format!("unknown kind: {other}"))),
    }
}

fn record_torrent_open(
    state: &LanServerState,
    device_token: &str,
    magnet: &str,
    info_hash: Option<&str>,
    stream_url: &str,
) {
    let hash = info_hash
        .map(|h| h.to_ascii_lowercase())
        .or_else(|| extract_info_hash(magnet))
        .unwrap_or_default();
    if hash.is_empty() {
        return;
    }
    let (device_id, device_label) = state
        .pairing
        .device_for_token(device_token)
        .unwrap_or_else(|| ("unknown".into(), None));
    let status = state.torrent.status();
    let name = status
        .as_ref()
        .map(|s| s.name.clone())
        .filter(|n| !n.is_empty())
        .or_else(|| magnet_display_name(magnet))
        .unwrap_or_else(|| hash.clone());
    let total_bytes = status.as_ref().map(|s| s.total_bytes).unwrap_or(0);
    let cache_file = file_name_from_url(stream_url);
    let opened_at = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    state.history.record(TorrentHistoryEntry {
        info_hash: hash,
        name,
        cache_file,
        device_id,
        device_label,
        opened_at,
        total_bytes,
    });
    if let Some(hook) = &state.on_history_changed {
        hook(&state.history);
    }
}

fn extract_info_hash(magnet: &str) -> Option<String> {
    let xt = magnet.split("xt=urn:btih:").nth(1)?;
    let hash = xt.split('&').next()?;
    if hash.is_empty() {
        return None;
    }
    Some(hash.to_ascii_lowercase())
}

fn magnet_display_name(magnet: &str) -> Option<String> {
    let query = magnet.strip_prefix("magnet:?").unwrap_or(magnet);
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        let k = parts.next()?;
        let v = parts.next().unwrap_or("");
        if k == "dn" {
            let decoded = urlencoding::decode(v).unwrap_or(v.into()).into_owned();
            let trimmed = decoded.replace('+', " ").trim().to_string();
            if !trimmed.is_empty() {
                return Some(trimmed);
            }
        }
    }
    None
}

fn file_name_from_url(url: &str) -> Option<String> {
    let path = url.split('?').next().unwrap_or(url);
    let name = path.rsplit('/').next().unwrap_or("");
    if name.is_empty() || name.contains("..") {
        return None;
    }
    let decoded = urlencoding::decode(name)
        .unwrap_or(name.into())
        .into_owned();
    if decoded.is_empty() {
        None
    } else {
        Some(decoded)
    }
}

fn rewrite_local_url(url: &str, host: &str, port: u16) -> String {
    for prefix in ["http://127.0.0.1:", "http://localhost:"] {
        if let Some(rest) = url.strip_prefix(prefix) {
            if let Some(path_start) = rest.find('/') {
                return format!("http://{host}:{port}{}", &rest[path_start..]);
            }
        }
    }
    url.to_string()
}

fn append_stream_ticket(url: &str, ticket: &str) -> String {
    let sep = if url.contains('?') { '&' } else { '?' };
    format!("{url}{sep}st={ticket}")
}

#[derive(Debug, Deserialize)]
struct SearchQuery {
    q: String,
}

async fn search_handler(
    State(_state): State<LanServerState>,
    Query(query): Query<SearchQuery>,
) -> impl IntoResponse {
    let results = scrapers::search_all(&query.q).await;
    Json(serde_json::json!({ "results": results }))
}

async fn status_handler(State(state): State<LanServerState>) -> impl IntoResponse {
    let status = state.torrent.status_json();
    Json(serde_json::from_str::<serde_json::Value>(&status).unwrap_or(serde_json::Value::Null))
}

fn bad_request(msg: &str) -> (StatusCode, Json<serde_json::Value>) {
    (
        StatusCode::BAD_REQUEST,
        Json(serde_json::json!({ "error": msg })),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{IpAddr, Ipv4Addr};

    #[tokio::test]
    async fn sticky_port_rebinds_after_close() {
        let first = bind_lan_listener(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::LOCALHOST),
            0,
        ))
        .await
        .expect("initial bind");
        let port = first.local_addr().unwrap().port();
        drop(first);
        let second = bind_lan_listener(SocketAddr::new(
            IpAddr::V4(Ipv4Addr::LOCALHOST),
            port,
        ))
        .await
        .expect("sticky rebind");
        assert_eq!(second.local_addr().unwrap().port(), port);
    }

    #[test]
    fn rewrite_swaps_loopback_host() {
        let url = "http://127.0.0.1:12345/torrents/1/stream/0/file.mkv";
        assert_eq!(
            rewrite_local_url(url, "192.168.1.10", 8765),
            "http://192.168.1.10:8765/torrents/1/stream/0/file.mkv"
        );
    }

    #[test]
    fn append_ticket_handles_existing_query() {
        assert_eq!(
            append_stream_ticket("http://h/p", "abc"),
            "http://h/p?st=abc"
        );
        assert_eq!(
            append_stream_ticket("http://h/p?x=1", "abc"),
            "http://h/p?x=1&st=abc"
        );
    }

    #[test]
    fn build_router_does_not_overlap_health() {
        // axum::merge panics on duplicate routes — regression for Settings → LAN enable.
        let state = LanServerState {
            pairing: PairingState::new("test-server".into()),
            proxy_state: ProxyState::default(),
            torrent: Arc::new(TorrentEngine::new()),
            history: TorrentHistory::default(),
            listen_port: Arc::new(tokio::sync::RwLock::new(0)),
            on_devices_changed: None,
            on_history_changed: None,
        };
        let _ = build_router(state);
    }

    #[test]
    fn parses_magnet_dn_and_stream_file() {
        let magnet = "magnet:?xt=urn:btih:abc123def4567890abc123def4567890abc123de&dn=Big%20Buck%20Bunny";
        assert_eq!(
            extract_info_hash(magnet).as_deref(),
            Some("abc123def4567890abc123def4567890abc123de")
        );
        assert_eq!(magnet_display_name(magnet).as_deref(), Some("Big Buck Bunny"));
        assert_eq!(
            file_name_from_url("http://h/torrents/1/stream/0/movie.mkv?st=x").as_deref(),
            Some("movie.mkv")
        );
    }

    #[test]
    fn close_request_deserializes_info_hash() {
        let r: CloseRequest =
            serde_json::from_str(r#"{"kind":"torrent","info_hash":"AbC"}"#).unwrap();
        assert_eq!(r.kind, "torrent");
        assert_eq!(r.info_hash.as_deref(), Some("AbC"));
    }
}
