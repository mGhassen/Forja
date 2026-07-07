# 001 — WebStreamr extraction blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/fixed/02-[fixed]-rust-engine-complete.md))  
**Status:** fixed (2026-07-06) — [EngineWorkerPool](../../packages/rust/lib/src/engine_worker.dart) + async Rust ([015](015-[fixed]-rust-blocking-http-engine-debt.md))  
**Root fix:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/api/lib/playback/webstreamr_service.dart`, `packages/rust/lib/src/isolate_runner.dart`, `crates/webstreamr`  
**Reported:** 2026-07-06

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Symptom** — UI thread blocks during resolve | **fixed** | `EngineWorkerPool` (3 workers) + typed job runners |
| **Root** — blocking HTTP, sequential 21 sources in Rust | **fixed** | [015](015-[fixed]-rust-blocking-http-engine-debt.md) |
| **Cancel** — abort in-flight Rust work | **fixed** | `Engine.cancelPendingResolve()` → `engine_cancel_pending` FFI |

## Root cause (before fix)

1. Sync FFI on the main isolate — `RustLib.instance.webstreamrGetStreamsJson()` blocked until Rust returned.
2. Blocking HTTP in Rust — `crates/webstreamr` uses `reqwest::blocking`, 20s timeout per request.
3. Sequential source resolution — all 21 sources queried one after another.

## Workaround (shipped — 2026-07-06)

Isolate offload — still required (R5). Engine async HTTP + parallel resolve shipped in [015](015-[fixed]-rust-blocking-http-engine-debt.md).

1. `runWebstreamrGetStreamsJson` in `packages/rust/lib/src/isolate_runner.dart` — loads Rust dylib in worker isolate.
2. `packages/api/lib/playback/webstreamr_service.dart:50`:

```dart
final raw = await runWebstreamrGetStreamsJson(jsonEncode(request));
```

3. `WebStreamrService.cancelPending()` — generation discard + `Engine.cancelPendingResolve()` aborts Rust HTTP.

**Verify:** `grep runWebstreamrGetStreamsJson packages/api` — no direct `RustLib.instance.webstreamrGetStreamsJson` in production.

## Root fix (shipped — [015](015-[fixed]-rust-blocking-http-engine-debt.md))

- [x] `crates/webstreamr`: async HTTP, parallel source resolve, early exit
- [x] Cancel token into Rust resolver ([009](009-[fixed]-post-migration-resilience-audit.md))
- [x] Optional: job API to reduce isolate spawn churn — `EngineWorkerPool` (pool size 3)

## If this file is deleted

Engine debt remains tracked in **[015](015-[fixed]-rust-blocking-http-engine-debt.md)**.

## Related

- [004](004-[fixed]-sync-ffi-ui-thread-audit.md) — parent audit
- `crates/webstreamr/src/resolver.rs`, `crates/webstreamr/src/fetcher.rs`
