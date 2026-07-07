use std::cell::RefCell;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};
pub use tokio_util::sync::CancellationToken;

static ROOT: LazyLock<Mutex<CancellationToken>> =
    LazyLock::new(|| Mutex::new(CancellationToken::new()));

static CANCEL_GENERATION: AtomicU64 = AtomicU64::new(0);

/// Shared token for the current job (rayon / multi-thread resolve).
static JOB_TOKEN_GLOBAL: LazyLock<Mutex<Option<CancellationToken>>> = LazyLock::new(|| Mutex::new(None));

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

/// Host Cancel — aborts in-flight HTTP and resets for new jobs.
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
}
