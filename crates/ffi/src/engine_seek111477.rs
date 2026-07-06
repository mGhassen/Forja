use proxy::seek111477::{Seek111477Proxy, Seek111477StartRequest, Seek111477StartResponse};
use std::sync::{LazyLock, Mutex};
use tokio::runtime::Runtime;

static SEEK: LazyLock<Mutex<Option<Seek111477Proxy>>> =
    LazyLock::new(|| Mutex::new(None));

pub fn seek111477_start(runtime: &Runtime, json: String) -> String {
    runtime
        .block_on(async {
            let req: Seek111477StartRequest = match serde_json::from_str(&json) {
                Ok(v) => v,
                Err(e) => {
                    return serde_json::to_string(&Seek111477StartResponse {
                        port: None,
                        url: None,
                        error: Some(e.to_string()),
                    })
                    .unwrap_or_else(|_| "{}".into());
                }
            };
            let existing = SEEK.lock().ok().and_then(|mut slot| slot.take());
            if let Some(existing) = existing {
                existing.stop().await;
            }
            match Seek111477Proxy::start(req).await {
                Ok(proxy) => {
                    let resp = Seek111477StartResponse {
                        port: Some(proxy.port()),
                        url: Some(proxy.url()),
                        error: None,
                    };
                    if let Ok(mut slot) = SEEK.lock() {
                        *slot = Some(proxy);
                    }
                    serde_json::to_string(&resp).unwrap_or_else(|_| "{}".into())
                }
                Err(e) => serde_json::to_string(&Seek111477StartResponse {
                    port: None,
                    url: None,
                    error: Some(e),
                })
                .unwrap_or_else(|_| "{}".into()),
            }
        })
}

pub fn seek111477_stop(runtime: &Runtime) {
    runtime.block_on(async {
        let proxy = SEEK.lock().ok().and_then(|mut slot| slot.take());
        if let Some(proxy) = proxy {
            proxy.stop().await;
        }
    });
}

pub fn seek111477_port() -> u16 {
    SEEK.lock()
        .ok()
        .and_then(|g| g.as_ref().map(Seek111477Proxy::port))
        .unwrap_or(0)
}

pub fn seek111477_is_running() -> bool {
    SEEK.lock().ok().and_then(|g| g.as_ref().map(|_| true)).unwrap_or(false)
}

pub fn seek111477_purge_cache(runtime: &Runtime, cache_dir: String) -> String {
    runtime
        .block_on(proxy::seek111477::purge_cache(&cache_dir))
        .map(|_| serde_json::json!({ "ok": true }).to_string())
        .unwrap_or_else(|e| serde_json::json!({ "error": e }).to_string())
}
