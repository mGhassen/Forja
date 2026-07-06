use std::cell::Cell;
use std::sync::atomic::{AtomicU64, Ordering};

static CANCEL_GENERATION: AtomicU64 = AtomicU64::new(0);

thread_local! {
    static JOB_START_GENERATION: Cell<u64> = const { Cell::new(0) };
}

/// Mark the start of a long-running FFI job on this thread (worker isolate).
pub fn enter_job() {
    JOB_START_GENERATION.set(CANCEL_GENERATION.load(Ordering::SeqCst));
}

/// Host Cancel — bumps generation; in-flight jobs started before this see [is_requested].
pub fn request() {
    CANCEL_GENERATION.fetch_add(1, Ordering::SeqCst);
}

pub fn is_requested() -> bool {
    let cancel_gen = CANCEL_GENERATION.load(Ordering::SeqCst);
    let job_gen = JOB_START_GENERATION.with(|g| g.get());
    cancel_gen > job_gen
}

pub fn cancelled_message() -> String {
    "cancelled".into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cancel_after_job_start() {
        enter_job();
        assert!(!is_requested());
        request();
        assert!(is_requested());
    }

    #[test]
    fn new_job_after_cancel_not_cancelled() {
        enter_job();
        request();
        assert!(is_requested());
        enter_job();
        assert!(!is_requested());
    }
}
