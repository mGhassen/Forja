use axum::{
    body::Body,
    extract::{Path, State},
    http::{header, StatusCode},
    response::Response,
    routing::get,
    Router,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct ProxyState {
    pub client: reqwest::Client,
    pub routes: Arc<RwLock<std::collections::HashMap<String, String>>>,
}

impl Default for ProxyState {
    fn default() -> Self {
        Self {
            client: reqwest::Client::new(),
            routes: Arc::new(RwLock::new(std::collections::HashMap::new())),
        }
    }
}

pub struct LocalProxy {
    state: ProxyState,
    shutdown: Option<tokio::sync::oneshot::Sender<()>>,
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
            .route("/proxy/{token}", get(proxy_handler))
            .with_state(self.state.clone());
        let addr = SocketAddr::from(([127, 0, 0, 1], port));
        let listener = tokio::net::TcpListener::bind(addr)
            .await
            .map_err(|e| e.to_string())?;
        let actual_port = listener.local_addr().map_err(|e| e.to_string())?.port();
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
    }
}

async fn health() -> &'static str {
    "ok"
}

async fn proxy_handler(
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
    let status = StatusCode::from_u16(resp.status().as_u16()).unwrap_or(StatusCode::BAD_GATEWAY);
    let bytes = resp.bytes().await.map_err(|_| StatusCode::BAD_GATEWAY)?;
    Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, "application/octet-stream")
        .body(Body::from(bytes))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn proxy_state_default() {
        let state = super::ProxyState::default();
        assert!(state.routes.try_read().is_ok());
    }
}
