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

// Per tokio task — parallel EngineJobs each keep their own token (Nuvio Job shape).
// Never share one process-global slot across concurrent extracts.
tokio::task_local! {
    static TASK_JOB_TOKEN: CancellationToken;
}

thread_local! {
    /// Blocking / sync FFI worker thread (spawn_blocking, enter_job).
    static JOB_TOKEN: RefCell<Option<CancellationToken>> = const { RefCell::new(None) };
}

/// Mark the start of a long-running FFI job on this thread (worker isolate / blocking task).
pub fn enter_job() {
    let token = ROOT.lock().unwrap().child_token();
    attach_job_token(token);
}

/// Attach a cancellation token for the current **blocking** thread.
/// Async EngineJobs must use [scope_job_token] instead — do not overwrite siblings.
pub fn attach_job_token(token: CancellationToken) {
    JOB_TOKEN.with(|t| *t.borrow_mut() = Some(token));
}

pub fn clear_job_token() {
    JOB_TOKEN.with(|t| *t.borrow_mut() = None);
}

/// Bind [token] for the duration of [fut] on this tokio task.
pub async fn scope_job_token<F, T>(token: CancellationToken, fut: F) -> T
where
    F: std::future::Future<Output = T>,
{
    TASK_JOB_TOKEN.scope(token, fut).await
}

/// Host Cancel — aborts in-flight playback HTTP and resets for new jobs.
/// Does **not** abort catalog paths that use [with_shutdown_cancel] only.
pub fn request() {
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
    if let Ok(t) = TASK_JOB_TOKEN.try_with(|t| t.clone()) {
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
    use std::sync::Mutex as StdMutex;

    /// Process-wide cancel/shutdown state is shared; serialize tests that mutate it.
    static CANCEL_TEST_LOCK: StdMutex<()> = StdMutex::new(());

    fn lock_tests() -> std::sync::MutexGuard<'static, ()> {
        CANCEL_TEST_LOCK
            .lock()
            .unwrap_or_else(|e| e.into_inner())
    }

    #[test]
    fn cancel_aborts_attached_job() {
        let _guard = lock_tests();
        clear_job_token();
        clear_shutdown();
        // Reset root so a prior [request] does not leave a cancelled parent.
        request();
        clear_job_token();
        let token = new_job_token();
        attach_job_token(token.clone());
        assert!(!token.is_cancelled());
        request();
        assert!(token.is_cancelled());
        clear_job_token();
    }

    #[tokio::test]
    async fn playback_cancel_does_not_abort_shutdown_only_path() {
        let _guard = lock_tests();
        clear_shutdown();
        clear_job_token();
        let fut = with_shutdown_cancel(async { Ok::<_, String>(42) });
        request();
        assert_eq!(fut.await.unwrap(), 42);
    }

    #[tokio::test]
    async fn shutdown_aborts_shutdown_only_path() {
        let _guard = lock_tests();
        clear_shutdown();
        clear_job_token();
        let handle = tokio::spawn(async {
            with_shutdown_cancel(std::future::pending::<Result<i32, String>>()).await
        });
        tokio::task::yield_now().await;
        request_shutdown();
        let err = handle.await.unwrap().unwrap_err();
        assert_eq!(err, cancelled_message());
        clear_shutdown();
        clear_job_token();
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn parallel_task_tokens_do_not_overwrite() {
        let _guard = lock_tests();
        clear_shutdown();
        request();
        clear_job_token();

        let a = new_job_token();
        let b = new_job_token();
        let (a_saw_cancel, b_still_live) = tokio::join!(
            scope_job_token(a.clone(), async {
                tokio::task::yield_now().await;
                let mine = cancellation_token();
                a.cancel();
                mine.is_cancelled()
            }),
            scope_job_token(b.clone(), async {
                tokio::task::yield_now().await;
                tokio::task::yield_now().await;
                !cancellation_token().is_cancelled() && !b.is_cancelled()
            }),
        );
        assert!(a_saw_cancel);
        assert!(b_still_live);
        assert!(!b.is_cancelled());
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn finishing_sibling_does_not_clear_peer_token() {
        let _guard = lock_tests();
        clear_shutdown();
        request();
        clear_job_token();

        let long = new_job_token();
        let short = new_job_token();
        let long_seen = tokio::spawn(scope_job_token(long.clone(), async {
            for _ in 0..32 {
                tokio::task::yield_now().await;
            }
            !cancellation_token().is_cancelled()
        }));
        let short_done = tokio::spawn(scope_job_token(short.clone(), async {
            tokio::task::yield_now().await;
            true
        }));
        assert!(short_done.await.unwrap());
        assert!(long_seen.await.unwrap());
        assert!(!long.is_cancelled());
    }
}
