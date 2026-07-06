# 007 — Torrent search/filter blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** workaround (2026-07-06) — UI no longer freezes; root cause open  
**Root fix:** [015](015-[open]-rust-blocking-http-engine-debt.md)  
**Area:** `packages/rust/lib/src/facade.dart`, player screens, `details_screen.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Symptom** — UI thread blocks on search/filter/sort | **workaround** | facade → isolate wrappers |
| **Root** — sync FFI + isolate spawn per search | **open** | [015](015-[open]-rust-blocking-http-engine-debt.md) |

## Root cause (before fix)

```dart
final json = RustLib.instance.searchTorrentsJson(query);  // facade, UI isolate
```

`Future(() => Engine.searchTorrents(...))` did **not** help — same UI isolate.

## Workaround (shipped — 2026-07-06)

Isolate offload — stops UI freeze but **does not fix** sync FFI + per-search isolate spawn. Root fix: [015](015-[open]-rust-blocking-http-engine-debt.md).

1. `runSearchTorrentsJson`, `runFilterTorrentsJson`, `runSortTorrentsJson` in `isolate_runner.dart`.
2. `facade.dart:149+` — `Engine.searchTorrents` / `filterTorrents` / `sortTorrents` await wrappers.

Call sites (`details_screen.dart`, player screens) unchanged — they already call async facade.

Tiny sync FFI kept on main isolate: `normalizeTorrentTitle`, `isVideoFile` (microsecond ops).

**Verify:** `grep runSearchTorrentsJson packages/rust/lib/src/facade.dart`

## Root fix (open)

Track in [015](015-[open]-rust-blocking-http-engine-debt.md): reduce per-search isolate churn; optional job API.

## If this file is deleted

Engine debt remains tracked in **[015](015-[open]-rust-blocking-http-engine-debt.md)**.

## Acceptance

- [x] Facade torrent search/filter/sort never block main isolate
- [ ] Manual test: details → torrent search on slow network — UI animates
