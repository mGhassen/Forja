# 015 — Rust blocking HTTP and sync resolve engine debt

**Priority:** P2  
**Severity:** Medium (perf, resource use, cancel waste — UI freeze workaround shipped)  
**Status:** fixed  
**Area:** `crates/webstreamr`, `crates/stremio-core`, `crates/scrapers`, `crates/ffi`, `crates/utils`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)  
**Related:** [009](009-[fixed]-post-migration-resilience-audit.md) (cancel-abort UX)

## Summary

Workarounds in [001](001-[fixed]-webstreamr-blocks-ui.md), [005](005-[fixed]-stremio-http-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md), [011](011-[fixed]-kisskh-hls-sync-ffi.md) offloaded sync FFI to worker isolates. **Root engine fix shipped:** async HTTP, parallel resolve, cancel-abort in Rust.

Dart `Isolate.run` remains required (R5) — it is not a substitute for async Rust but still mandatory so sync FFI never runs on the UI thread.

## Root fix (shipped)

1. **Async HTTP** — `webstreamr`/`stremio-core`: shared `reqwest::Client` + tokio runtime; sync API wraps `block_on`.
2. **Parallel resolve** — `webstreamr`: rayon parallel primary sources, early exit at 8 playable URLs.
3. **Cancellable jobs** — `utils::engine_cancel`: generation counter + per-thread `enter_job()`; `engine_cancel_pending()` FFI; checked in fetcher, resolver, stremio HTTP. Dart `cancelPending()` calls `Engine.cancelPendingResolve()`.
4. **Deferred (optional):** ~~async job/poll FFI~~ — shipped as Dart-side `EngineWorkerPool`.

## Acceptance

- [x] `webstreamr` uses async HTTP (`fetcher.rs`)
- [x] `webstreamr` primary sources resolve in parallel with early exit (`resolver.rs`)
- [x] `stremio-core` uses shared async HTTP client + runtime
- [x] Cancel from host aborts in-flight resolve in Rust (`engine_cancel.rs`, `engine_cancel_pending` FFI, Dart wiring)
- [x] [RFC-009](../rfc/009-rust-ffi.md) threading section updated
- [x] Profile: long resolve no longer spawns new isolate per call — `EngineWorkerPool` (3 persistent workers)

## Verify

```bash
cargo test --workspace
```

Cancel: start WebStreamr/Vidsrc resolve, tap Cancel — Rust stops at next HTTP boundary; worker isolate may still exit after partial work.

## Files

| File | Change |
|------|--------|
| `crates/utils/src/engine_cancel.rs` | Generation-based cancel token |
| `crates/webstreamr/src/fetcher.rs` | Cancel checks before async fetch |
| `crates/webstreamr/src/resolver.rs` | Cancel checks in parallel + fallback loops |
| `crates/stremio-core/src/http.rs` | Cancel checks in fetch |
| `crates/ffi/src/lib.rs`, `c_api.rs`, `forja.udl` | `engine_cancel_pending`, `enter_job` on long FFI |
| `packages/rust/lib/src/engine_worker.dart` | Persistent worker pool (3 isolates) |
| `packages/rust/lib/src/isolate_runner.dart` | Typed job runners |
| `packages/rust/lib/src/engine.dart`, `facade.dart` | `engineCancelPending`, `Engine.cancelPendingResolve`, pool start at init |
| `packages/api/lib/playback/webstreamr_service.dart`, `vidsrc_extractor.dart` | Wire cancel to Rust |
