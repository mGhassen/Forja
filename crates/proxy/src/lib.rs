use axum::{
    body::Body,
    extract::{Path, Query, Request, State},
    http::{header, HeaderMap, Method, StatusCode},
    middleware::{self, Next},
    response::Response,
    routing::get,
    Router,
};
use futures_util::TryStreamExt;
use serde::Deserialize;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;

use hls::HlsAheadCache;

mod comic;
pub mod ext;
mod hls;
mod jellyfin;
pub mod seek111477;
mod subtitlecat;
mod toky;

/// Query key the host appends to every loopback media URL.
pub const PROXY_TOKEN_QUERY_KEY: &str = "proxy_token";
/// Header alternative for players that can set request headers.
pub const PROXY_TOKEN_HEADER: &str = "x-forja-proxy-token";
/// Random bytes behind the token (hex-encoded → 64 chars).
const PROXY_TOKEN_BYTES: usize = 32;

/// `/ext/{id}/…` sessions are capability URLs: the id is random
/// ([`ext::EXT_SESSION_ID_BYTES`]) and relative child URIs cannot carry a query.
const CAPABILITY_PATH_PREFIX: &str = "/ext/";

fn new_proxy_token() -> String {
    let bytes: [u8; PROXY_TOKEN_BYTES] = rand::random();
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[derive(Clone)]
pub struct ProxyState {
    pub client: reqwest::Client,
    pub routes: Arc<RwLock<HashMap<String, String>>>,
    pub listen_port: Arc<RwLock<u16>>,
    pub sessions: Arc<RwLock<HashMap<String, ext::ExtSession>>>,
    /// Unwrapped HLS segments fetched ahead of the player (image-shelled live).
    pub hls_ahead: HlsAheadCache,
    /// Per-process secret every loopback media request must present.
    pub auth_token: Arc<String>,
}

impl Default for ProxyState {
    fn default() -> Self {
        Self {
            client: reqwest::Client::builder()
                .redirect(reqwest::redirect::Policy::limited(8))
                .build()
                .unwrap_or_else(|_| reqwest::Client::new()),
            routes: Arc::new(RwLock::new(HashMap::new())),
            listen_port: Arc::new(RwLock::new(0)),
            sessions: Arc::new(RwLock::new(HashMap::new())),
            hls_ahead: HlsAheadCache::default(),
            auth_token: Arc::new(new_proxy_token()),
        }
    }
}

impl ProxyState {
    /// Token the host must append as `?proxy_token=` (or send as
    /// [`PROXY_TOKEN_HEADER`]) on loopback media routes.
    pub fn auth_token(&self) -> &str {
        self.auth_token.as_str()
    }

    /// `http://127.0.0.1:{port}{route}?proxy_token=…` — base for URLs the proxy
    /// hands back to the player (rewritten playlists, redirects).
    pub async fn local_route_base(&self, route: &str) -> String {
        let port = *self.listen_port.read().await;
        format!(
            "http://127.0.0.1:{port}{route}?{PROXY_TOKEN_QUERY_KEY}={}",
            self.auth_token
        )
    }
}

/// Append the loopback token to a proxy URL built elsewhere.
pub fn with_proxy_token(url: &str, token: &str) -> String {
    let sep = if url.contains('?') { '&' } else { '?' };
    format!("{url}{sep}{PROXY_TOKEN_QUERY_KEY}={token}")
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

fn query_param(query: &str, key: &str) -> Option<String> {
    url::form_urlencoded::parse(query.as_bytes())
        .find(|(k, v)| k == key && !v.is_empty())
        .map(|(_, v)| v.into_owned())
}

/// Loopback gate: 403 unless the request carries the process token.
/// `/ext/{id}/…` is exempt — its random id is the capability.
async fn require_proxy_token(
    State(state): State<ProxyState>,
    req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    if req.uri().path().starts_with(CAPABILITY_PATH_PREFIX) {
        return Ok(next.run(req).await);
    }
    let presented = req
        .headers()
        .get(PROXY_TOKEN_HEADER)
        .and_then(|v| v.to_str().ok())
        .map(str::to_owned)
        .or_else(|| query_param(req.uri().query().unwrap_or(""), PROXY_TOKEN_QUERY_KEY));
    match presented {
        Some(t) if constant_time_eq(t.as_bytes(), state.auth_token.as_bytes()) => {
            Ok(next.run(req).await)
        }
        _ => Err(StatusCode::FORBIDDEN),
    }
}

pub struct LocalProxy {
    pub state: ProxyState,
    shutdown: Option<tokio::sync::oneshot::Sender<()>>,
}

impl Default for LocalProxy {
    fn default() -> Self {
        Self::new()
    }
}

impl LocalProxy {
    pub fn new() -> Self {
        Self {
            state: ProxyState::default(),
            shutdown: None,
        }
    }

    pub async fn register_route(&self, token: &str, upstream_url: &str) {
        self.state
            .routes
            .write()
            .await
            .insert(token.to_string(), upstream_url.to_string());
    }

    pub async fn start(&mut self, port: u16) -> Result<u16, String> {
        let app = proxy_router(self.state.clone());
        let addr = SocketAddr::from(([127, 0, 0, 1], port));
        let listener = tokio::net::TcpListener::bind(addr)
            .await
            .map_err(|e| e.to_string())?;
        let actual_port = listener.local_addr().map_err(|e| e.to_string())?.port();
        let mut stored = self.state.listen_port.write().await;
        *stored = actual_port;
        let (tx, rx) = tokio::sync::oneshot::channel();
        self.shutdown = Some(tx);
        tokio::spawn(async move {
            axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = rx.await;
                })
                .await
                .ok();
        });
        Ok(actual_port)
    }

    pub fn stop(&mut self) {
        if let Some(tx) = self.shutdown.take() {
            let _ = tx.send(());
        }
        if let Ok(mut port) = self.state.listen_port.try_write() {
            *port = 0;
        }
    }
}

/// Media/proxy routes only (no `/health`). LAN remounts these and supplies its own health.
pub fn proxy_media_router(state: ProxyState) -> Router {
    proxy_media_routes().with_state(state)
}

/// Loopback LocalProxy: token-gated media routes + open `/health`.
/// The LAN remount ([`proxy_media_router`]) brings its own pairing/ticket layer.
pub fn proxy_router(state: ProxyState) -> Router {
    proxy_media_routes()
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            require_proxy_token,
        ))
        .route("/health", get(health))
        .with_state(state)
}

fn proxy_media_routes() -> Router<ProxyState> {
    Router::new()
        .route("/proxy", get(query_proxy_handler).head(query_proxy_handler))
        .route(
            "/hls-proxy",
            get(hls::hls_proxy_handler).head(hls::hls_proxy_handler),
        )
        .route(
            "/ext/{id}/{*path}",
            get(ext::ext_proxy_handler).head(ext::ext_proxy_handler),
        )
        .route("/proxy/{token}", get(token_proxy_handler))
        .route("/toky-proxy", get(toky::toky_proxy_handler))
        .route("/comic-proxy", get(comic::comic_proxy_handler))
        .route(
            "/jellyfin-stream",
            get(jellyfin::jellyfin_stream_handler).head(jellyfin::jellyfin_stream_handler),
        )
        .route(
            "/subtitlecat-translate",
            get(subtitlecat::subtitlecat_translate_handler),
        )
}

#[derive(Debug, Deserialize)]
struct ProxyQuery {
    url: String,
    headers: Option<String>,
}

async fn health() -> &'static str {
    "ok"
}

fn parse_custom_headers(raw: Option<&str>) -> HashMap<String, String> {
    let Some(raw) = raw.filter(|s| !s.is_empty()) else {
        return HashMap::new();
    };
    serde_json::from_str(raw).unwrap_or_default()
}

fn header_ci<'a>(custom_headers: &'a HashMap<String, String>, name: &str) -> Option<&'a str> {
    custom_headers
        .iter()
        .find(|(k, _)| k.eq_ignore_ascii_case(name))
        .map(|(_, v)| v.as_str())
}

fn build_upstream_request(
    state: &ProxyState,
    method: Method,
    target_url: &str,
    custom_headers: &HashMap<String, String>,
    incoming: &HeaderMap,
) -> Result<reqwest::RequestBuilder, StatusCode> {
    let mut req = state.client.request(method, target_url);
    let ua = header_ci(custom_headers, "User-Agent")
        .map(str::to_owned)
        .unwrap_or_else(|| {
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36".into()
        });
    req = req.header(header::USER_AGENT, ua);
    if let Some(referer) = header_ci(custom_headers, "Referer") {
        req = req.header(header::REFERER, referer);
    } else {
        req = req.header(header::REFERER, "https://www.youtube.com/");
    }
    if let Some(origin) = header_ci(custom_headers, "Origin") {
        req = req.header(header::ORIGIN, origin);
    }
    if let Some(cookie) = header_ci(custom_headers, "Cookie") {
        req = req.header(header::COOKIE, cookie);
    }
    if let Some(auth) = header_ci(custom_headers, "Authorization") {
        req = req.header(header::AUTHORIZATION, auth);
    }
    req = req.header(header::ACCEPT, "*/*");
    req = req.header(header::ACCEPT_LANGUAGE, "en-US,en;q=0.9");
    req = req.header(header::ACCEPT_ENCODING, "identity");
    req = req.header(header::CONNECTION, "keep-alive");
    if let Some(range) = incoming.get(header::RANGE) {
        req = req.header(header::RANGE, range);
    }
    Ok(req)
}

fn forward_response(resp: reqwest::Response) -> Result<Response, StatusCode> {
    let status = StatusCode::from_u16(resp.status().as_u16()).unwrap_or(StatusCode::BAD_GATEWAY);
    // No CORS headers: only the host's players call this loopback server.
    let mut builder = Response::builder()
        .status(status)
        .header(header::ACCEPT_RANGES, "bytes")
        .header(header::CONNECTION, "keep-alive");

    for key in [
        header::CONTENT_TYPE,
        header::CONTENT_LENGTH,
        header::CONTENT_RANGE,
        header::ACCEPT_RANGES,
        header::CONTENT_DISPOSITION,
        header::ETAG,
        header::LAST_MODIFIED,
    ] {
        if let Some(v) = resp.headers().get(&key) {
            builder = builder.header(key, v);
        }
    }

    let stream = resp.bytes_stream().map_err(std::io::Error::other);
    builder
        .body(Body::from_stream(stream))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

async fn query_proxy_handler(
    State(state): State<ProxyState>,
    Query(query): Query<ProxyQuery>,
    method: Method,
    headers: HeaderMap,
) -> Result<Response, StatusCode> {
    let target_url = urlencoding::decode(&query.url)
        .map(|s| s.into_owned())
        .unwrap_or(query.url);
    let custom = parse_custom_headers(query.headers.as_deref());
    let req = build_upstream_request(&state, method, &target_url, &custom, &headers)?;
    let resp = req.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
    forward_response(resp)
}

async fn token_proxy_handler(
    State(state): State<ProxyState>,
    Path(token): Path<String>,
) -> Result<Response, StatusCode> {
    let upstream = {
        let routes = state.routes.read().await;
        routes.get(&token).cloned()
    };
    let Some(upstream) = upstream else {
        return Err(StatusCode::NOT_FOUND);
    };
    let resp = state
        .client
        .get(&upstream)
        .send()
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?;
    forward_response(resp)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn proxy_state_default() {
        let state = ProxyState::default();
        assert!(state.routes.try_read().is_ok());
    }

    #[tokio::test]
    async fn registers_route() {
        let proxy = LocalProxy::new();
        proxy
            .register_route("tok", "https://example.com/stream")
            .await;
        let routes = proxy.state.routes.read().await;
        assert_eq!(
            routes.get("tok").map(String::as_str),
            Some("https://example.com/stream")
        );
    }

    #[test]
    fn parses_custom_headers_json() {
        let map = parse_custom_headers(Some(r#"{"Referer":"https://example.com/"}"#));
        assert_eq!(
            map.get("Referer").map(String::as_str),
            Some("https://example.com/")
        );
    }

    #[test]
    fn proxy_tokens_are_random_and_long() {
        let a = ProxyState::default();
        let b = ProxyState::default();
        assert_eq!(a.auth_token().len(), PROXY_TOKEN_BYTES * 2);
        assert_ne!(a.auth_token(), b.auth_token());
        assert!(a.auth_token().chars().all(|c| c.is_ascii_hexdigit()));
    }

    #[test]
    fn with_proxy_token_picks_separator() {
        assert_eq!(
            with_proxy_token("http://127.0.0.1:1/hls-proxy?url=x", "t"),
            "http://127.0.0.1:1/hls-proxy?url=x&proxy_token=t"
        );
        assert_eq!(
            with_proxy_token("http://127.0.0.1:1/proxy/abc", "t"),
            "http://127.0.0.1:1/proxy/abc?proxy_token=t"
        );
    }

    #[tokio::test]
    async fn local_route_base_carries_token() {
        let state = ProxyState::default();
        *state.listen_port.write().await = 4242;
        let base = state.local_route_base("/hls-proxy").await;
        assert_eq!(
            base,
            format!(
                "http://127.0.0.1:4242/hls-proxy?proxy_token={}",
                state.auth_token()
            )
        );
    }

    async fn status_of(router: Router, uri: &str, header_token: Option<&str>) -> StatusCode {
        use tower::ServiceExt;
        let mut req = Request::builder().uri(uri);
        if let Some(t) = header_token {
            req = req.header(PROXY_TOKEN_HEADER, t);
        }
        let req = req.body(Body::empty()).unwrap();
        router.oneshot(req).await.unwrap().status()
    }

    #[tokio::test]
    async fn loopback_gate_rejects_missing_and_wrong_token() {
        let state = ProxyState::default();
        let router = proxy_router(state.clone());
        assert_eq!(
            status_of(
                router.clone(),
                "/proxy?url=https%3A%2F%2Fexample.com%2F",
                None
            )
            .await,
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            status_of(
                router.clone(),
                "/proxy?url=https%3A%2F%2Fexample.com%2F&proxy_token=nope",
                None
            )
            .await,
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            status_of(router.clone(), "/hls-proxy?url=x", Some("wrong")).await,
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            status_of(router.clone(), "/proxy/sometoken", None).await,
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            status_of(router.clone(), "/comic-proxy?url=x", None).await,
            StatusCode::FORBIDDEN
        );
        // Health stays open.
        assert_eq!(status_of(router, "/health", None).await, StatusCode::OK);
    }

    #[tokio::test]
    async fn loopback_gate_passes_valid_token_to_handler() {
        let state = ProxyState::default();
        let router = proxy_router(state.clone());
        // Unknown route token → handler reached and answers 404 (not 403).
        let uri = format!("/proxy/unknown?proxy_token={}", state.auth_token());
        assert_eq!(
            status_of(router.clone(), &uri, None).await,
            StatusCode::NOT_FOUND
        );
        assert_eq!(
            status_of(router, "/proxy/unknown", Some(state.auth_token())).await,
            StatusCode::NOT_FOUND
        );
    }

    #[tokio::test]
    async fn ext_sessions_are_capability_urls() {
        let state = ProxyState::default();
        let router = proxy_router(state);
        // No token, unknown session → 404 from the handler, not 403 from the gate.
        assert_eq!(
            status_of(router, "/ext/nosuch/index.mpd", None).await,
            StatusCode::NOT_FOUND
        );
    }

    #[test]
    fn forward_response_sends_no_cors_headers() {
        let upstream = axum::http::Response::builder()
            .status(200)
            .header(header::CONTENT_TYPE, "video/mp2t")
            .body("abc".to_string())
            .unwrap();
        let resp = forward_response(reqwest::Response::from(upstream)).unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        assert!(resp
            .headers()
            .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
            .is_none());
        assert!(resp
            .headers()
            .get(header::ACCESS_CONTROL_ALLOW_METHODS)
            .is_none());
        assert!(resp
            .headers()
            .get(header::ACCESS_CONTROL_ALLOW_HEADERS)
            .is_none());
        assert_eq!(
            resp.headers().get(header::CONTENT_TYPE).unwrap(),
            "video/mp2t"
        );
    }
}
