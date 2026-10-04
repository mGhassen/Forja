# 402 — macOS Intel: Continue Watching row empty

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `packages/rust/lib/src/watch_history_service.dart` · Continue Watching mount

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I402-T01 | Home continue mapping no longer hard-casts season/episode (`watchHistoryIntOrNull`) | ✅ |
| 2 | I402-T02 | `watchHistoryInt` parses numeric strings; `watchHistoryIntOrNull` for optional fields | ✅ |
| 3 | I402-T03 | When Rust engine is not loaded, watch history reads/writes `forja_engine_store.json` directly | ✅ |
| 4 | I402-T04 | Continue mount logs reload failures; reloads when history already seeded | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I402-A01 | Intel Mac: after watching past 2%, Home Continue Watching lists the title (engine loaded or store-file fallback) | ⬜ |

---

## Summary

Home Continue Watching pulls in-progress rows from `WatchHistoryService` (engine KV). On **macOS Intel**, a missing/wrong-arch `libffi.dylib` leaves `Engine.isReady == false`, so KV reads returned `[]` and writes were skipped — the Continue widget mounts as `SizedBox.shrink()`. A second failure mode: TV history rows with `season`/`episode` stored as JSON doubles threw on `as int?` inside `catalogEntryFromHomeWatchHistory`, and `_ContinueMount._reload` swallowed the error.

### Fix

- Coerce season/episode/ids with `watchHistoryInt` / `watchHistoryIntOrNull`
- File-backed watch history when the Rust engine did not load (same JSON map as the engine store)
- Skip `duration <= 0` saves so handoff cannot poison a good row
- Continue mount: log reload errors; reload when history is already loaded (broadcast stream miss)

### Related

- [176](../176-[workaround]-macos-intel-metal-text-glitch.md) — Intel Metal glyph garbage (painted row looks broken; different from empty mount)
- [327](327-[fixed]-continue-watching-saved-hls-url-no-reextract.md) — resume extract path
