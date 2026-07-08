# 022 — No widget/integration tests for playback cancel and slow FFI

**Priority:** P3  
**Severity:** Low  
**Status:** draft  
**Parent:** [018](018-[draft]-migration-playback-parity-unverified.md)  
**Area:** `apps/forja/test/`, `packages/rust/test/`  
**Reported:** 2026-07-07  
**Deferred from:** [009](fixed/009-[fixed]-post-migration-resilience-audit.md) acceptance (“widget/integration tests — not started”)
## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** acceptance |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

Playback migration has **123+ Rust parity unit tests** and a few E2E smokes (`engine_smoke_test.dart`, mobile magnet E2E). There are **no widget or integration tests** that:

- Mock slow `EngineJobs` / `WebStreamrService` responses
- Assert Cancel discards in-flight work without applying stale UI state
- Assert streaming details / player show correct source count and `video_library` button

Regressions like [017](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) were caught manually, not by CI.

## Proposed tests (minimal)

| Test | Asserts |
|------|---------|
| `streaming_details_screen` + fake `WebStreamrService` | N sources pushed to player route |
| `WebStreamrService` cancel | Second call not blocked; gen discard returns `[]` only when cancelled |
| Player with `sources.length == 1` | `video_library` control visible (regression for 017) |
| `details_screen` torrent gen-token | Stale `Engine.searchTorrents` result not applied after gen bump |

Use `flutter_test` + dependency injection or test doubles — avoid live network in CI.


## Related

- [008](fixed/008-[fixed]-ci-enforce-no-sync-ffi.md) — sync FFI grep (complementary)
- [020](020-[draft]-cancel-gen-token-discard-unverified.md) — manual QA for same behavior
