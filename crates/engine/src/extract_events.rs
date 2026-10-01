//! Rows pushed by `ctx.emit` while an extract job is still running.
//! Keyed by EngineJobs id. A job id of 0 (unit tests that call `extract`) is ignored.

use std::collections::{HashMap, VecDeque};
use std::sync::{Mutex, OnceLock};

const MAX_ROWS: usize = 48;

fn queues() -> &'static Mutex<HashMap<u64, VecDeque<String>>> {
    static Q: OnceLock<Mutex<HashMap<u64, VecDeque<String>>>> = OnceLock::new();
    Q.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn push(job_id: u64, row_json: String) {
    if job_id == 0 {
        return;
    }
    let row = row_json.trim();
    if !row.starts_with('{') {
        return;
    }
    let mut guard = queues().lock().unwrap_or_else(|e| e.into_inner());
    let q = guard.entry(job_id).or_default();
    if q.len() >= MAX_ROWS {
        return;
    }
    q.push_back(row.to_string());
}

/// Drain queued row JSON objects as a JSON array. Empty when nothing was emitted.
pub fn take(job_id: u64) -> String {
    if job_id == 0 {
        return "[]".into();
    }
    let mut guard = queues().lock().unwrap_or_else(|e| e.into_inner());
    let Some(q) = guard.get_mut(&job_id) else {
        return "[]".into();
    };
    let rows: Vec<String> = q.drain(..).collect();
    if rows.is_empty() {
        return "[]".into();
    }
    format!("[{}]", rows.join(","))
}

pub fn clear(job_id: u64) {
    if job_id == 0 {
        return;
    }
    let mut guard = queues().lock().unwrap_or_else(|e| e.into_inner());
    guard.remove(&job_id);
}
