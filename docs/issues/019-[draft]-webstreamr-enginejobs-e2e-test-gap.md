# 019 — WebStreamr live E2E test bypasses app path (EngineJobs)

**Priority:** P2  
**Severity:** Medium  
**Status:** draft  
**Parent:** [018](018-[draft]-migration-playback-parity-unverified.md)  
**Area:** `packages/rust/test/parity/`, `packages/api/lib/playback/webstreamr_service.dart`, `packages/rust/lib/src/engine_jobs.dart`  
**Reported:** 2026-07-07
## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** acceptance |
| **Backlog** | [1.0.0](../backlog/1.0.0-[draft].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

Live WebStreamr parity is only partially covered. [`webstreamr_enola_live_test.dart`](../../packages/rust/test/parity/webstreamr_enola_live_test.dart) calls **`RustLib.instance.webstreamrGetStreamsJson` directly** (sync FFI in the test isolate). The production app path is:

`WebStreamrService.getStreams()` → `runWebstreamrGetStreamsJson()` → **`EngineJobs.run(EngineAsyncJob.webstreamrGetStreams)`** → generation-token discard on cancel.

A regression in job submission, result polling, or Dart mapping could pass the live Rust test while the app returns an empty list — the exact failure mode seen before [017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md).

## Root cause

Test was written to validate Rust resolver output quickly; it does not exercise the async job FFI layer or `WebStreamrService` mapping (`resolveStreamUrl`, 1shows HLS proxy, skip logging).

## Fix

1. Add integration test: `WebStreamrService().getStreams(imdbId: 'tt32278481', isMovie: true, tmdbId: 1202033)` with live network (`@Tags(['live'])` or `#[ignore]` + CI opt-in).
2. Assert `length >= 10`, at least one source title contains `HDHub4u`.
3. Optional: compare raw job JSON count vs final `StreamSource` count (mapping should not drop playable entries).

```bash
cd packages/rust && flutter test test/parity/webstreamr_service_e2e_test.dart --tags live
```


## Related

- [017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) — prior list-loss regression
- [001](fixed/001-[fixed]-webstreamr-blocks-ui.md) — UI blocking (fixed)
- [016](fixed/016-[fixed]-async-job-ffi-hard-cancel.md) — EngineJobs infrastructure
