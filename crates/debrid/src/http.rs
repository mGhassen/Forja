use std::sync::LazyLock;
use std::time::Duration;

use tokio::runtime::Runtime;

static RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("debrid tokio runtime"));

pub fn client(timeout: Duration) -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .timeout(timeout)
        .redirect(reqwest::redirect::Policy::limited(10))
        .build()
        .map_err(|e| e.to_string())
}

pub fn block_on<F: std::future::Future>(f: F) -> F::Output {
    RUNTIME.block_on(f)
}

pub async fn sleep_secs(secs: u64) {
    tokio::time::sleep(Duration::from_secs(secs)).await;
}
