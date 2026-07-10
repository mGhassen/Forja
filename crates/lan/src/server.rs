use axum::{
    extract::{Query, State},
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
use tokio::sync::oneshot;
use torrent::{torrent_stream_router, TorrentAppState, TorrentEngine};

use crate::auth::require_bearer_token;
use crate::bind::LanBindMode;
use crate::mdns::MdnsAnnouncer;
use crate::pairing::{PairRequest, PairResponse, PairingState, RevokeRequest};

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Clone)]
pub struct LanServerState {
    pub pairing: PairingState,
    pub proxy_state: ProxyState,
    pub torrent: Arc<TorrentEngine>,
    pub listen_port: Arc<tokio::sync::RwLock<u16>>,
}

pub struct LanServer {
    shutdown: Option<oneshot::Sender<()>>,
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
            mdns: None,
            state: LanServerState {
                pairing: PairingState::new(server_id),
                proxy_state,
                torrent,
                listen_port: Arc::new(tokio::sync::RwLock::new(0)),
            },
        }
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

        if self.state.torrent.engine_port() == 0 {
            self.state
                .torrent
                .start_engine(preferred_port)
                .map_err(|e| e.to_string())?;
        }

        let app = build_router(self.state.clone());
        let addr = SocketAddr::new(bind_mode.bind_addr(), preferred_port);
        let listener = tokio::net::TcpListener::bind(addr)
            .await
            .map_err(|e| e.to_string())?;
        let port = listener.local_addr().map_err(|e| e.to_string())?.port();
        *self.state.listen_port.write().await = port;

        let (tx, rx) = oneshot::channel();
        self.shutdown = Some(tx);
        tokio::spawn(async move {
            axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = rx.await;
                })
                .await
                .ok();
        });

        if bind_mode == LanBindMode::AllInterfaces {
            let server_id = self.state.pairing.server_id();
            self.mdns = Some(MdnsAnnouncer::announce(&server_id, port, VERSION)?);
        }

        self.state.pairing.refresh_code();
        Ok(port)
    }

    pub fn stop(&mut self) {
        if let Some(tx) = self.shutdown.take() {
            let _ = tx.send(());
        }
        self.mdns.take();
        if let Ok(mut port) = self.state.listen_port.try_write() {
            *port = 0;
        }
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
    let mut streams = proxy::proxy_router(state.proxy_state.clone());
    if let Some(api) = state.torrent.torrent_api() {
        streams = streams.merge(torrent_stream_router(TorrentAppState { api }));
    }
    streams = streams.route_layer(middleware::from_fn(move |req, next| {
        let pairing = stream_pairing.clone();
        async move { require_bearer_token(pairing, req, next).await }
    }));

    public.merge(protected).merge(streams)
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
    Ok(Json(PairResponse {
        token,
        server_id: state.pairing.server_id(),
    }))
}

async fn devices_handler(State(state): State<LanServerState>) -> Json<Vec<crate::pairing::DeviceRecord>> {
    Json(state.pairing.list_devices())
}

async fn revoke_handler(
    State(state): State<LanServerState>,
    Json(body): Json<RevokeRequest>,
) -> impl IntoResponse {
    let ok = state.pairing.revoke_device(&body.device_id);
    Json(serde_json::json!({ "ok": ok }))
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
    Json(body): Json<OpenRequest>,
) -> Result<Json<OpenResponse>, (StatusCode, Json<serde_json::Value>)> {
    let port = *state.listen_port.read().await;
    let host = body
        .host
        .filter(|h| !h.is_empty())
        .unwrap_or_else(|| "127.0.0.1".to_string());
    let base = format!("http://{host}:{port}");

    match body.kind.as_str() {
        "direct" => {
            let url = body
                .upstream_url
                .filter(|u| !u.is_empty())
                .ok_or_else(|| bad_request("upstream_url required for direct"))?;
            Ok(Json(OpenResponse {
                play_url: url,
                headers: body.headers,
            }))
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
            let play_url = format!("{base}/proxy/{token}");
            Ok(Json(OpenResponse {
                play_url,
                headers: body.headers,
            }))
        }
        "torrent" => {
            let magnet = body
                .magnet
                .filter(|m| !m.is_empty())
                .ok_or_else(|| bad_request("magnet required for torrent"))?;
            let raw = state.torrent.stream_magnet_json(
                &magnet,
                body.season,
                body.episode,
                body.file_idx,
            );
            let parsed: serde_json::Value =
                serde_json::from_str(&raw).map_err(|_| bad_request("torrent resolve failed"))?;
            if let Some(err) = parsed.get("error").and_then(|v| v.as_str()) {
                return Err(bad_request(err));
            }
            let url = parsed
                .get("url")
                .and_then(|v| v.as_str())
                .ok_or_else(|| bad_request("torrent resolve missing url"))?;
            let play_url = rewrite_local_url(url, &host, port);
            Ok(Json(OpenResponse {
                play_url,
                headers: None,
            }))
        }
        other => Err(bad_request(&format!("unknown kind: {other}"))),
    }
}

fn rewrite_local_url(url: &str, host: &str, port: u16) -> String {
    if let Some(rest) = url.strip_prefix("http://127.0.0.1:") {
        if let Some(path_start) = rest.find('/') {
            return format!("http://{host}:{port}{}", &rest[path_start..]);
        }
    }
    if let Some(rest) = url.strip_prefix("http://localhost:") {
        if let Some(path_start) = rest.find('/') {
            return format!("http://{host}:{port}{}", &rest[path_start..]);
        }
    }
    url.to_string()
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

    #[test]
    fn rewrites_loopback_torrent_url() {
        let url = "http://127.0.0.1:12345/torrents/1/stream/0/file.mkv";
        assert_eq!(
            rewrite_local_url(url, "192.168.1.10", 8765),
            "http://192.168.1.10:8765/torrents/1/stream/0/file.mkv"
        );
    }
}
