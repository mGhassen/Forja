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

## Solution (2026-07-06)

1. Added wrappers in `packages/rust/lib/src/isolate_runner.dart`:
   - `runSearchTorrentsJson(query)`
   - `runFilterTorrentsJson(resultsJson, showTitle, {requiredSeason, requiredEpisode})`
   - `runSortTorrentsJson(resultsJson, preference)`
2. Updated `packages/rust/lib/src/facade.dart` — `Engine.searchTorrents`, `filterTorrents`, and `sortTorrents` now `await` the wrappers. Call sites in `details_screen.dart`, `desktop_player_screen.dart`, and `mobile_player_screen.dart` are unchanged (they already call the async facade).

`Future(() => Engine.searchTorrents(...))` was never sufficient — the FFI ran on the UI isolate regardless. The facade wrappers fix that at the source.

Tiny sync FFI kept on main isolate: `normalizeTorrentTitle`, `isVideoFile` (microsecond ops).

### Not done (follow-up)

- Per-source progress callback from Rust during search

## Acceptance

- [x] Facade torrent search/filter/sort never block main isolate
- [ ] Manual test: open movie details → torrent search on slow network — UI animates
- [ ] [004](004-[open]-sync-ffi-ui-thread-audit.md) facade row marked fixed
