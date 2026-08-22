# 195 — Anime hub cold open waits on serial AniList + TMDB

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/features/anime/providers/anime_catalog_provider.dart`, `anime_screen.dart`, `anime_screen_feed.dart`  
**Reported:** 2026-08-22

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 5** fix · **0 / 4** acceptance |
| **Current slice** | Symptom: parallel AniList sections + TMDB after first paint — root (batched query / progressive rows / disk cache) open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I195-T01 | Parallelize hub AniList section fetches (`Future.wait`) — stop serial RTT sum | ✅ |
| 2 | I195-T02 | Return catalog bundle before TMDB; wire `_enrichSpotlightTmdb` after `_applyCatalogBundle` | ✅ |
| 3 | I195-T03 | Progressive UI: unlock hero/rows after trending (or per-section) without gating on full bundle | ⬜ |
| 4 | I195-T04 | Batched / multi-alias AniList GraphQL for hub sections (one HTTP round-trip) | ⬜ |
| 5 | I195-T05 | Disk/memory catalog cache with TTL (survive tab eviction / cold process) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I195-A01 | Cold Anime tab: first meaningful paint after AniList sections resolve — not after TMDB hero enrich | ⬜ |
| 2 | I195-A02 | Cold open wall time dominated by parallel AniList waves, not 7 serial GraphQL calls | ⬜ |
| 3 | I195-A03 | Soft refresh keeps previous hero/rows visible until new bundle applies | ⬜ |
| 4 | I195-A04 | Root: batched query and/or disk cache — reopen after tab eviction does not always hit full network | ⬜ |

---

## Summary

Opening the Anime tab showed a long skeleton because first paint waited on `animeCatalogProvider` → `_loadAnimeCatalog`, which **serially awaited** seven AniList GraphQL queries, then **awaited TMDB** backdrop enrich for five hero titles, before `_applyCatalogBundle` set section futures.

## Symptom fix (shipped)

- `Future.wait` all hub AniList sections in `_loadAnimeCatalog`
- Provider returns AniList spotlight immediately; screen calls `_enrichSpotlightTmdb` after apply so hero swaps cinematic backdrops without blocking first paint

**Not a root fix** — still one full-bundle gate, still N AniList HTTP calls (worker pool ~3), no catalog disk cache.

## Root fix (open)

- Progressive section UI (T03)
- Single batched AniList query (T04)
- Catalog cache with TTL (T05)

## Related

- Provider: `anime_catalog_provider.dart`
- Screen apply / enrich: `anime_screen.dart`, `anime_screen_feed.dart`
- Feature guide: [anime.md](../features/hubs/anime.md)
