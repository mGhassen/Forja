# 021 — Catalog vertical import migration smoke unverified

**Priority:** P3  
**Severity:** Low  
**Status:** open  
**Parent:** [018](018-[open]-migration-playback-parity-unverified.md)  
**Area:** `apps/forja/lib/features/`, `packages/api/lib/api/`  
**Reported:** 2026-07-07

## Summary

~14 content verticals were **not engine-migrated** (Phase 3 scope). On the migration branch they only changed package imports: `forja_api` → `api`, `forja_storage` → `packages/rust` / `apps/forja/lib/shared/theme/app_theme.dart`. All 56 feature screens still exist; no vertical was removed.

**No smoke pass** has confirmed each vertical still loads lists and opens detail/play flows after the rename.

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
- `forja_core/models` → `api/models`
- Error handling added in some screens (e.g. `anime_screen` mood load returns `[]` on catch) — behavior change vs main on network failure

## Acceptance

- [ ] Each vertical row: list loads without import/runtime error
- [ ] At least one item opens detail and play/read path
- [ ] Failures filed as separate bugs with screen + stack trace

## Related

- [018](018-[open]-migration-playback-parity-unverified.md) — playback parity (higher priority)
