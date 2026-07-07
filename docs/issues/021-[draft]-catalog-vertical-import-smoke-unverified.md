# 021 — Catalog vertical import migration smoke unverified

**Priority:** P3  
**Severity:** Low  
**Status:** draft  
**Parent:** [018](018-[draft]-migration-playback-parity-unverified.md)  
**Area:** `apps/forja/lib/features/`, `packages/rust/lib/src/catalog/`  
**Reported:** 2026-07-07
## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** acceptance |
| **Backlog** | [1.0.0](../backlog/1.0.0-[open].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

~14 content verticals keep **C2 scrape/orchestration in `apps/forja`** (host exceptions). P3-04 moved metadata/subtitle/music/debrid to Rust. Package rename: `forja_api` → `rust`; `forja_storage` theme → `app_theme.dart`.

**No manual smoke pass** has confirmed each vertical still loads lists and opens detail/play flows on device.

## Verticals to smoke (open → load list → open one item → play/read)

| Vertical | Screens | Service |
|----------|---------|---------|
| Anime | `anime_*` (5) | `anime_service.dart` |
| Anime Arabic | `anime_arabic_*` (4) | `anime_arabic_service.dart` |
| Asian Drama | `asian_drama_*` (5) | `kisskh_service.dart` |
| Arabic | `arabic_*` (3) | `arabic_service.dart` |
| Manga | `manga_*` (3) | `manga_service.dart` |
| Comics | `comics_*` (3) | `comics_service.dart` |
| Books | `books_*` (2) | `books_service.dart` |
| Music | `music_*` (2) | `music_*` services |
| Audiobooks | `audiobook_*` (4) | `audiobook_*` services |
| Jellyfin | `jellyfin_*` (2) | `jellyfin_service.dart` |
| Similar | `similar_*` (2) | `bestsimilar_scraper.dart` |
| Live matches | `live_matches_screen` | (in-screen) |
| Downloader | `media_downloader_screen` | (in-screen) |
| My List / Lists | `my_list_*`, `lists_screen` | `my_list_service.dart` |

Also spot-check: **Discover**, **Search**, **Settings** (non-playback sections).

## Known rename risks

- `forja_storage` theme → `app_theme.dart` — palette/atmosphere widgets
- `forja_core/models` → `packages/rust/lib/src/models/`
- Error handling added in some screens (e.g. `anime_screen` mood load returns `[]` on catch) — behavior change vs main on network failure


## Automated checks (2026-07-07)

| Check | Result |
|-------|--------|
| `rg "package:api" apps/forja packages/rust` | **0 matches** |
| `dart analyze apps/forja` | pass (warnings only, no errors) |
| `apps/forja/test/engine_smoke_test.dart` | **13 passed** |

**Still open:** manual device smoke for each vertical row in the table above.

## Related

- [018](018-[draft]-migration-playback-parity-unverified.md) — playback parity (higher priority)
