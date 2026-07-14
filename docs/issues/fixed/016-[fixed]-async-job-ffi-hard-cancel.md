# 016 — Async job FFI + hard cancel

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `crates/utils`, `crates/ffi`, `packages/rust`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06  
**Extends:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** |
| **Backlog** | [0.4.0](../backlog/done/0.4.0-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I16-F01 | Async job FFI hard cancel shipped | ✅ |

---


## Summary

[015](015-[fixed]-rust-blocking-http-engine-debt.md) shipped async HTTP, worker pool, and cooperative cancel. This issue completes the **limitation fix**:

1. **Hard cancel** — `CancellationToken` + `tokio::select!` aborts in-flight reqwest (not just between hops).
2. **Async job FFI** — long I/O runs on Rust tokio runtime; Dart main isolate polls via `EngineJobs` (no worker blocked for whole resolve).

## Shipped

| Layer | Implementation |
|-------|----------------|
| Cancel token | `crates/utils/src/engine_cancel.rs` — `CancellationToken`, `with_cancel()`, `attach_job_token()` for rayon/blocking threads |
| HTTP abort | `webstreamr/fetcher`, `stremio/http`, `scrapers/search` |
| Job API | `crates/ffi/src/engine_jobs.rs` — `engine_submit_job`, `engine_take_job_result`, `engine_cancel_pending` → `cancel_all()` |
| Dart | `EngineJobs.run()` + `EngineWorkerPool` for CPU jobs in `isolate_runner.dart` |
| Cancel UX | `cancel_all()` marks pending jobs `{"error":"cancelled"}` so poll loop never hangs |

## I/O vs CPU split

| Path | Mechanism |
|------|-----------|
| webstreamr, vidsrc, stremio HTTP, torrent search, IPTV HTTP/probe | `EngineJobs` |
| filter/sort, M3U/HLS parse, kisskh decrypt, xtream parse, videasy AES | `EngineWorkerPool` |

## Deferred

- Native port callback (`Dart_PostCObject`) instead of poll — optional perf polish
- Single shared tokio runtime across all crates (webstreamr still has own runtime inside blocking jobs)

## Verify

```bash
./scripts/build_rust.sh
cargo test --workspace
cd packages/rust && flutter test test/parity/engine_jobs_test.dart
```

Cancel: start resolve → Cancel → `EngineJobs` future completes with `cancelled`, HTTP aborted mid-flight.
