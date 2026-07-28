use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, HeaderMap, Method, StatusCode},
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

mod hls;
pub mod index111477;
pub mod mega;
pub mod seek111477;
mod toky;
mod comic;
mod jellyfin;
mod subtitlecat;

#[derive(Clone)]
pub struct ProxyState {
    pub client: reqwest::Client,
    pub routes: Arc<RwLock<HashMap<String, String>>>,
    pub listen_port: Arc<RwLock<u16>>,
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
        }
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
        let app = Router::new()
            .route("/health", get(health))
            .route(
                "/proxy",
                get(query_proxy_handler).head(query_proxy_handler),
            )
            .route(
                "/hls-proxy",
                get(hls::hls_proxy_handler).head(hls::hls_proxy_handler),
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
            .with_state(self.state.clone());
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

fn header_ci<'a>(
    custom_headers: &'a HashMap<String, String>,
    name: &str,
) -> Option<&'a str> {
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
    let mut builder = Response::builder()
        .status(status)
        .header(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")
        .header(header::ACCESS_CONTROL_ALLOW_METHODS, "GET, HEAD, OPTIONS, POST")
        .header(header::ACCESS_CONTROL_ALLOW_HEADERS, "*")
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

    let stream = resp
        .bytes_stream()
        .map_err(std::io::Error::other);
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
        assert_eq!(map.get("Referer").map(String::as_str), Some("https://example.com/"));
    }
}
