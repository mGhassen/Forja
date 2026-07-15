# 061 — Engine worker hang on quit (AniList uncancellable)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/utils` · `crates/stremio` · `EngineWorkerPool` · app shutdown  
**Reported:** 2026-07-15  
**Fixed:** 2026-07-15

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I61-T01 | Add `request_shutdown` / `with_shutdown_cancel` distinct from playback cancel | ✅ |
| 2 | I61-T02 | AniList unchecked HTTP aborts on shutdown; KissKh retries check shutdown | ✅ |
| 3 | I61-T03 | `Engine.shutdown` → `enginePrepareShutdown` + cooperative worker `Isolate.exit` | ✅ |
| 4 | I61-T04 | Parity tests: playback cancel keeps catalog; shutdown aborts worker AniList | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I61-A01 | Playback `engineCancelPending` does not fail in-flight AniList (catalog) | ✅ |
| 2 | I61-A02 | `enginePrepareShutdown` aborts worker-pool AniList so isolates can exit | ✅ |

---

## Summary

Quitting after opening **Anime** (or Asian Drama while KissKh retried) left `flutter run` stuck on:

`waiting for isolate forja-engine-worker-N to check in`

**Root cause:** AniList catalog uses `fetch_post_with_headers_unchecked` so **playback** cancel does not kill background feeds. That path ignored cancel entirely, so a worker blocked in `block_on` could not exit when `Isolate.kill` ran — the Dart VM waited for check-in until the connection dropped.

**Fix:** Process teardown uses a separate shutdown latch (`request_shutdown` / `with_shutdown_cancel`). Playback cancel behavior is unchanged. `Engine.shutdown` calls `enginePrepareShutdown`, then asks workers to `Isolate.exit` after FFI returns, then force-kills.

## Verify

```bash
./scripts/build_rust.sh
cd crates && cargo test -p utils engine_cancel
cd packages/rust && flutter test test/parity/anilist_manga_test.dart
```

Manual: open Anime (and Asian Drama) → quit — process should exit without isolate check-in spam.
