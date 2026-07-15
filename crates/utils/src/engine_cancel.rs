use std::cell::RefCell;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};
use tokio::sync::Notify;
pub use tokio_util::sync::CancellationToken;

static ROOT: LazyLock<Mutex<CancellationToken>> =
    LazyLock::new(|| Mutex::new(CancellationToken::new()));

static CANCEL_GENERATION: AtomicU64 = AtomicU64::new(0);

/// Process teardown — aborts catalog HTTP that ignores playback [request].
static SHUTDOWN: AtomicBool = AtomicBool::new(false);
static SHUTDOWN_NOTIFY: LazyLock<Notify> = LazyLock::new(Notify::new);

/// Shared token for the current job (rayon / multi-thread resolve).
static JOB_TOKEN_GLOBAL: LazyLock<Mutex<Option<CancellationToken>>> =
    LazyLock::new(|| Mutex::new(None));

thread_local! {
    static JOB_TOKEN: RefCell<Option<CancellationToken>> = const { RefCell::new(None) };
}

/// Mark the start of a long-running FFI job on this thread (worker isolate / blocking task).
pub fn enter_job() {
    let token = ROOT.lock().unwrap().child_token();
    attach_job_token(token);
}

/// Attach a cancellation token for the current in-flight job.
pub fn attach_job_token(token: CancellationToken) {
    *JOB_TOKEN_GLOBAL.lock().unwrap() = Some(token.clone());
    JOB_TOKEN.with(|t| *t.borrow_mut() = Some(token));
}

pub fn clear_job_token() {
    *JOB_TOKEN_GLOBAL.lock().unwrap() = None;
    JOB_TOKEN.with(|t| *t.borrow_mut() = None);
}

/// Host Cancel — aborts in-flight playback HTTP and resets for new jobs.
/// Does **not** abort catalog paths that use [with_shutdown_cancel] only.
pub fn request() {
    if let Some(token) = JOB_TOKEN_GLOBAL.lock().unwrap().take() {
        token.cancel();
    }
    let mut root = ROOT.lock().unwrap();
    root.cancel();
    *root = CancellationToken::new();
    CANCEL_GENERATION.fetch_add(1, Ordering::SeqCst);
    JOB_TOKEN.with(|t| *t.borrow_mut() = None);
}

/// App exit — abort playback **and** catalog HTTP so worker isolates can unwind.
pub fn request_shutdown() {
    SHUTDOWN.store(true, Ordering::SeqCst);
    SHUTDOWN_NOTIFY.notify_waiters();
    request();
}

pub fn is_shutdown_requested() -> bool {
    SHUTDOWN.load(Ordering::SeqCst)
}

/// Clear shutdown latch (engine init / tests after [request_shutdown]).
pub fn clear_shutdown() {
    SHUTDOWN.store(false, Ordering::SeqCst);
}

pub fn cancellation_token() -> CancellationToken {
    if let Some(t) = JOB_TOKEN_GLOBAL.lock().unwrap().clone() {
        return t;
    }
    JOB_TOKEN.with(|t| {
        t.borrow()
            .clone()
            .unwrap_or_else(|| ROOT.lock().unwrap().child_token())
    })
}

pub fn new_job_token() -> CancellationToken {
    ROOT.lock().unwrap().child_token()
}

pub fn is_requested() -> bool {
    cancellation_token().is_cancelled()
}

pub fn cancelled_message() -> String {
    "cancelled".into()
}

/// Run an async operation, aborting promptly when the job token is cancelled.
pub async fn with_cancel<F, T>(fut: F) -> Result<T, String>
where
    F: std::future::Future<Output = Result<T, String>>,
{
    let token = cancellation_token();
    tokio::select! {
        res = fut => res,
        _ = token.cancelled() => Err(cancelled_message()),
    }
}

/// Catalog HTTP: ignore playback [request], abort on [request_shutdown].
pub async fn with_shutdown_cancel<F, T>(fut: F) -> Result<T, String>
where
    F: std::future::Future<Output = Result<T, String>>,
{
    let notified = SHUTDOWN_NOTIFY.notified();
    tokio::pin!(notified);
    if is_shutdown_requested() {
        return Err(cancelled_message());
    }
    tokio::select! {
        res = fut => res,
        _ = &mut notified => Err(cancelled_message()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cancel_aborts_attached_job() {
        let token = new_job_token();
        attach_job_token(token.clone());
        assert!(!token.is_cancelled());
        request();
        assert!(token.is_cancelled());
        clear_job_token();
    }

    #[tokio::test]
    async fn playback_cancel_does_not_abort_shutdown_only_path() {
        clear_shutdown();
        let fut = with_shutdown_cancel(async { Ok::<_, String>(42) });
        request();
        assert_eq!(fut.await.unwrap(), 42);
    }

    #[tokio::test]
    async fn shutdown_aborts_shutdown_only_path() {
        clear_shutdown();
        let handle = tokio::spawn(async {
            with_shutdown_cancel(std::future::pending::<Result<i32, String>>()).await
        });
        tokio::task::yield_now().await;
        request_shutdown();
        let err = handle.await.unwrap().unwrap_err();
        assert_eq!(err, cancelled_message());
        clear_shutdown();
    }
}
