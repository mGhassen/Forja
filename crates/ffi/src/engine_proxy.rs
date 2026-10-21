use proxy::LocalProxy;
use std::sync::{LazyLock, Mutex};
use tokio::runtime::Runtime;

static PROXY: LazyLock<Mutex<LocalProxy>> = LazyLock::new(|| Mutex::new(LocalProxy::new()));
static PROXY_PORT: LazyLock<Mutex<u16>> = LazyLock::new(|| Mutex::new(0));

/// Start a fresh loopback proxy. Any previous instance is shut down first, so
/// every start mints a new `ProxyState` (new auth token, empty routes/sessions).
pub fn proxy_start(runtime: &Runtime, preferred_port: u16) -> i32 {
    runtime
        .block_on(async {
            let mut fresh = LocalProxy::new();
            {
                let mut slot = PROXY.lock().ok()?;
                slot.stop();
            }
            if let Ok(mut stored) = PROXY_PORT.lock() {
                *stored = 0;
            }
            let started = fresh.start(preferred_port).await.ok();
            *PROXY.lock().ok()? = fresh;
            let port = started?;
            if let Ok(mut stored) = PROXY_PORT.lock() {
                *stored = port;
            }
            Some(port)
        })
        .map(|p| p as i32)
        .unwrap_or(-1)
}

pub fn proxy_stop() {
    if let Ok(mut proxy) = PROXY.lock() {
        proxy.stop();
    }
    if let Ok(mut port) = PROXY_PORT.lock() {
        *port = 0;
    }
}

pub fn proxy_port() -> u16 {
    PROXY_PORT.lock().map(|p| *p).unwrap_or(0)
}

/// Loopback auth token minted with the current proxy (new one per `proxy_start`).
/// Empty when the proxy is not running.
pub fn proxy_token() -> String {
    if proxy_port() == 0 {
        return String::new();
    }
    PROXY
        .lock()
        .map(|p| p.state.auth_token().to_string())
        .unwrap_or_default()
}

pub fn proxy_state() -> Option<proxy::ProxyState> {
    PROXY.lock().ok().map(|p| p.state.clone())
}

pub fn proxy_register_route(runtime: &Runtime, token: String, upstream_url: String) -> bool {
    runtime
        .block_on(async {
            let state = PROXY.lock().ok()?.state.clone();
            state.routes.write().await.insert(token, upstream_url);
            Some(())
        })
        .is_some()
}

pub fn proxy_create_ext_session(runtime: &Runtime, url: String, headers_json: String) -> String {
    runtime
        .block_on(async {
            // Clone the state inside a block so the std mutex guard is released
            // before the await.
            let state = {
                let Ok(proxy) = PROXY.lock() else {
                    return None;
                };
                proxy.state.clone()
            };
            proxy::ext::create_ext_session(&state, &url, &headers_json).await
        })
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_rotates_per_start_and_clears_on_stop() {
        let rt = Runtime::new().unwrap();
        let port_a = proxy_start(&rt, 0);
        assert!(port_a > 0);
        let token_a = proxy_token();
        assert_eq!(token_a.len(), 64);

        proxy_stop();
        assert_eq!(proxy_port(), 0);
        assert_eq!(proxy_token(), "");

        let port_b = proxy_start(&rt, 0);
        assert!(port_b > 0);
        let token_b = proxy_token();
        assert_eq!(token_b.len(), 64);
        assert_ne!(token_a, token_b, "stop → start must mint a new token");

        // Start while running also rotates (fresh state replaces the old one).
        let port_c = proxy_start(&rt, 0);
        assert!(port_c > 0);
        assert_ne!(proxy_token(), token_b);

        proxy_stop();
        assert_eq!(proxy_token(), "");
    }
}
