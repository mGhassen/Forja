use proxy::LocalProxy;
use std::sync::{LazyLock, Mutex};
use tokio::runtime::Runtime;

static PROXY: LazyLock<Mutex<LocalProxy>> = LazyLock::new(|| Mutex::new(LocalProxy::new()));
static PROXY_PORT: LazyLock<Mutex<u16>> = LazyLock::new(|| Mutex::new(0));

pub fn proxy_start(runtime: &Runtime, preferred_port: u16) -> i32 {
    runtime
        .block_on(async {
            let mut proxy = PROXY.lock().ok()?;
            let port = proxy.start(preferred_port).await.ok()?;
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

pub fn proxy_register_route(runtime: &Runtime, token: String, upstream_url: String) -> bool {
    runtime
        .block_on(async {
            let proxy = PROXY.lock().ok()?;
            proxy.register_route(&token, &upstream_url).await;
            Some(())
        })
        .is_some()
}
