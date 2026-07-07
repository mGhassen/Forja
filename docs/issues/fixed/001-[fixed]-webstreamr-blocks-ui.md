# 001 — WebStreamr extraction blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Tracked:** P2-91 ([Phase 2 task](../migration/fixed/02-[fixed]-rust-engine-complete.md))  
**Status:** fixed (2026-07-06) — [EngineWorkerPool](../../packages/rust/lib/src/engine_worker.dart) + async Rust ([015](015-[fixed]-rust-blocking-http-engine-debt.md))  
**Root fix:** [015](015-[fixed]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/api/lib/playback/webstreamr_service.dart`, `packages/rust/lib/src/isolate_runner.dart`, `crates/webstreamr`  
**Reported:** 2026-07-06
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · symptom ✅ · root ✅ |
| **Backlog** | [0.4.2](../backlog/done/0.4.2-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Layers

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I01-L01 | Symptom — UI thread blocks during resolve | ✅ |
| 2 | I01-L02 | Root — blocking HTTP, sequential sources in Rust | ✅ |
| 3 | I01-L03 | Cancel — abort in-flight Rust work | ✅ |

---

## Root fix ([015](015-[fixed]-rust-blocking-http-engine-debt.md))

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I01-R01 | `crates/webstreamr`: async HTTP, parallel resolve, early exit | ✅ |
| 2 | I01-R02 | Cancel token into Rust resolver | ✅ |
| 3 | I01-R03 | `EngineWorkerPool` (3 persistent workers) | ✅ |

---



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


## If this file is deleted

Engine debt remains tracked in **[015](015-[fixed]-rust-blocking-http-engine-debt.md)**.

## Related

- [004](004-[fixed]-sync-ffi-ui-thread-audit.md) — parent audit
- `crates/webstreamr/src/resolver.rs`, `crates/webstreamr/src/fetcher.rs`
