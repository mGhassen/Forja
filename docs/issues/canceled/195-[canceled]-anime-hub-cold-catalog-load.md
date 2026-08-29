# 195 — Anime hub cold open waits on serial AniList + TMDB

**Status:** canceled  
**Priority:** P2  
**Severity:** Medium  
**Area:** CatalogShell · `plugins/hubs/anilist.js` (was `anime_catalog_provider` / `AnimeScreen`)  
**Reported:** 2026-08-22

## Status at a glance

| | |
|--|--|
| **Progress** | **Canceled** — legacy Anime browse path retired (RFC-070 A20) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I195-T01 | Parallelize hub AniList section fetches (`Future.wait`) — stop serial RTT sum | ✅ |
| 2 | I195-T02 | Return catalog bundle before TMDB; wire `_enrichSpotlightTmdb` after `_applyCatalogBundle` | ✅ |
| 3 | I195-T03 | Progressive UI: unlock hero/rows after trending (or per-section) without gating on full bundle | ✅ |
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

## Why canceled

RFC-070 **A20** deleted `AnimeScreen` / `anime_catalog_provider`. Browse is **CatalogShell** + hubs pack `anilist` — rails fetch in parallel per widget; `CatalogRuntime` already caches envelopes (ETag / TTL / SWR). Symptom tasks T01–T03 applied only to the retired Dart hub.

Remaining pack-side batch GraphQL (old T04) is optional pack work, not this issue’s Dart screen.

## Related

- [RFC-070](../rfc/070-[partial]-catalog-hub-protocol.md)
- Feature guide: [anime.md](../features/hubs/anime.md)
