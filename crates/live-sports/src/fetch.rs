use std::collections::HashMap;
use std::sync::LazyLock;
use std::time::Duration;

use serde_json::{json, Value};
use tokio::runtime::Runtime;

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("live-matches tokio runtime"));

static CLIENT: LazyLock<reqwest::Client> = LazyLock::new(|| {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .expect("live-matches http client")
});

pub(crate) fn ok_items(items: Vec<Value>) -> String {
    json!({ "items": items }).to_string()
}

pub(crate) fn ok_items_epg_batch(
    items: Vec<Value>,
    epg_more: bool,
    epg_next_offset: usize,
) -> String {
    json!({
        "items": items,
        "epg_more": epg_more,
        "epg_next_offset": epg_next_offset,
    })
    .to_string()
}

pub(crate) fn block_on<F: std::future::Future>(fut: F) -> F::Output {
    RUNTIME.block_on(fut)
}

pub(crate) async fn http_get_async(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
    utils::engine_cancel::with_cancel(async {
        let timeout = Duration::from_secs(timeout_secs.max(1));
        let mut req = CLIENT.get(url).timeout(timeout);
        for (k, v) in headers {
            req = req.header(k.as_str(), v.as_str());
        }
        let resp = req.send().await.map_err(|e| e.to_string())?;
        if !resp.status().is_success() {
            return Err(format!("http {}", resp.status()));
        }
        resp.text().await.map_err(|e| e.to_string())
    })
    .await
    .ok()
}

pub(crate) fn http_get(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
    RUNTIME.block_on(http_get_async(url, headers, timeout_secs))
}

/// Alias for callers that want a clearer name (JSON body as text).
pub(crate) fn http_get_json(
    url: &str,
    headers: &HashMap<String, String>,
    timeout_secs: u64,
) -> Option<String> {
    http_get(url, headers, timeout_secs)
}
