# 007 — Torrent search/filter blocks the UI thread

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `packages/rust/lib/src/facade.dart`, `apps/forja/lib/features/home/details_screen.dart`, player screens  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

`Engine.searchTorrents()` and `Engine.filterTorrents()` call sync Rust FFI (`searchTorrentsJson`, `filterTorrentsJson`) on the main isolate. Scraper search can take tens of seconds across multiple sources. `Future(() => Engine.searchTorrents(...))` **does not help** — still runs on the UI isolate.

## Call sites

| File | Pattern |
|------|---------|
| `details_screen.dart` | `_searchTorrents`, season/episode search |
| `desktop_player_screen.dart` | provider switch torrent search |
| `mobile_player_screen.dart` | provider switch torrent search |

## Root cause

```dart
// packages/rust/lib/src/facade.dart
final json = RustLib.instance.searchTorrentsJson(query);
```

## Impact

- Detail screen torrent tab frozen while searching
- Player provider switch feels dead
- Worst case: user force-quits during long search

## Fix

- Move `searchTorrentsJson`, `filterTorrentsJson`, `sortTorrentsJson` behind `runRustIsolate` in facade or isolate_runner
- Consider progress callback from Rust for per-source status (UX follow-up)

## Acceptance

- [ ] Facade torrent search/filter/sort never block main isolate
- [ ] Manual test: open movie details → torrent search on slow network — UI animates
- [ ] [004](004-[open]-sync-ffi-ui-thread-audit.md) facade row marked fixed
