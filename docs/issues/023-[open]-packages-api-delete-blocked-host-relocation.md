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
| Deleted legacy bridge file | ~~`packages/api/lib/api/anime_http.dart`~~ |
| Call sites import `package:rust/rust.dart` | `packages/api/lib/api/*` (26 files) |

## Blockers to full delete

1. **`apps/forja`** — 80+ `package:api/` imports (UI, providers, playback wiring).
2. **Host slices still in `packages/api`:** `lib/services/`, `lib/playback/`, models, `my_list`, Jellyfin wrappers, extractors (C3 WebView).
3. **Dart engine debt:** HTML parse / orchestration in `lib/api/*` (C2 should be Rust per `ENGINE_BOUNDARY.md`); thin FFI wrappers (e.g. `tmdb_api.dart`) still parse in Dart.
4. **Remaining Dart HTTP** (deferred playback wave): `debrid_api.dart`, `site111477_service.dart`, `mega_proxy.dart`, `jackett_service.dart`, `prowlarr_service.dart`, `link_resolver.dart`, `app_updater_service.dart`, `youtube_audio_extractor.dart`, `videasy_extractor.dart`.

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
