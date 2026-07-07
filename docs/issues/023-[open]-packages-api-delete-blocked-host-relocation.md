# P3-03 — `packages/api` delete blocked until host relocation

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Phase:** [P3-03](../migration/03-engine-catalog.md)  
**Related:** [021 catalog vertical smoke](021-[open]-catalog-vertical-import-smoke-unverified.md)

---

## Summary

Phase 3 task P3-03 cannot delete `packages/api` wholesale yet. Catalog HTTP was rewired to Rust (`anime-core` via `packages/rust`), but the package still holds models, host orchestration, playback glue, WebView extractors, and Dart HTML parsing.

## Shipped (incremental)

| Change | Location |
|--------|----------|
| Catalog HTTP FFI bridge moved out of `packages/api` | `packages/rust/lib/src/catalog_http.dart` (`animeHttp`, `animeHttpBytes`) |
| Shared catalog/playback DTOs moved out of `packages/api` | `packages/rust/lib/src/models/` (`Movie`, `StreamSource`, `StreamResult`, `TorrentResult`) |
| Deleted legacy bridge file | ~~`packages/api/lib/api/anime_http.dart`~~ |
| Deleted legacy model files | ~~`packages/api/lib/models/*.dart`~~ (`api.dart` re-exports from `rust`) |
| Host player services relocated | `pip_service`, `external_player_service`, `player_pool_service`, `android_player_launcher` → `apps/forja/lib/shared/services/` |
| Host updater relocated | `app_updater_service` → `apps/forja/lib/shared/services/` |
| Episode watched relocated | `episode_watched_service` → `packages/rust`; sync in `tracker_sync.dart` |
| My list + book progress relocated | `my_list_service`, `book_progress_service`, `BookResult` → `packages/rust` |
| Playback glue relocated | 11 playback modules + `webstreamr_settings` → `packages/rust`; `stremio_stream_resolver` remains in `api` (needs `debrid_api`) |
| Catalog metadata relocated | `introdb`, `mdblist`, `subtitlecat`, `mysubs`, `tmdb_service`, `paper2audio` → `packages/rust/lib/src/catalog/` |
| Host player/audiobook utils | `track_auto_select`, `epub_cover`, `epub_splitter` → `apps/forja` |
| Music/audio host cluster | `audio_handler`, `music_player_service`, `audiobook_player_service`, `music_storage`, `music_downloader`, `lyrics_service` → `apps/forja/lib/shared/audio/` |
| TMDB API + KissKh subtitle decrypt | `tmdb_api`, `kisskh_subtitle_decryptor` → `packages/rust/lib/src/catalog/` |
| Call sites import `package:rust/rust.dart` | `packages/api/lib/api/*` (26 files) |

## Blockers to full delete

1. **`apps/forja`** — 80+ `package:api/` imports (UI, providers, playback wiring).
2. **Host slices still in `packages/api`:** `lib/api/*` catalog parsers, `lib/services/` (6 engine services), `lib/playback/stremio_stream_resolver.dart` (debrid-coupled), extractors (C3 WebView).
3. **Dart engine debt:** HTML parse / orchestration in `lib/api/*` (C2 should be Rust per `ENGINE_BOUNDARY.md`); thin FFI wrappers (e.g. `tmdb_api.dart`) still parse in Dart.
4. **Remaining Dart HTTP in `packages/api`** (deferred playback wave): `debrid_api.dart`, `site111477_service.dart`, `mega_proxy.dart`, `jackett_service.dart`, `prowlarr_service.dart`, `link_resolver.dart`, `youtube_audio_extractor.dart`, `videasy_extractor.dart`.

## Acceptance criteria (P3-03 done)

- [ ] Relocate host-appropriate code to `apps/forja` (or split `packages/forja_core` if needed).
- [ ] Delete migrated Dart catalog slices after Rust ports (not just rewire HTTP).
- [ ] Remove `packages/api` from workspace `pubspec.yaml` / melos.
- [ ] `rg 'package:api/'` → zero outside archived docs.
- [ ] Exit checklist A1–A4 in [03-engine-catalog.md](../migration/03-engine-catalog.md) ✅.

## Suggested next steps

1. Inventory `package:api` imports by category (models vs playback vs catalog).
2. Move models + host services into `apps/forja` first (lowest engine risk).
3. Port or delete remaining `lib/api/*` Dart parsers per vertical.
4. Drop `http` from `packages/api/pubspec.yaml` only when last consumer is gone.

## Symptom vs root

| Layer | State |
|-------|--------|
| **Symptom** | Catalog HTTP off UI thread via `runAnimeRequestJson` + worker pool |
| **Root** | `anime-core` still blocking `reqwest` internally — see [015](015-[fixed]-rust-blocking-http-engine-debt.md) / engine debt tracking |

This issue tracks **package deletion / host relocation**, not Rust async HTTP.
