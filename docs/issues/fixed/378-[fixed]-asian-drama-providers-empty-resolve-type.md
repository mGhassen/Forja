# 378 — Asian Drama Sources empty (drama resolveType + TMDB title miss)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/hubs/asian_drama` · Sources Forja · `sources_request_context`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I378-T01 | Pack: stamp `open.extract.resolveType` as `movie`/`tv` (keep `panelCategory=drama`) | ✅ |
| 2 | I378-T02 | Pack: TMDB enrich updates resolveType; drama title normalize for bilingual KissKH names | ✅ |
| 3 | I378-T03 | Host: remap pack `drama` → `movie`/`tv` via `tmdbMediaType` in Sources / green Play | ✅ |
| 4 | I378-T04 | Host test: drama + `tmdbMediaType=movie` → engine type movie, panel stays drama | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I378-A01 | Asian Drama movie with TMDB match: Forja logs `tmdb=<id> type=movie` (not `type=drama` / `/tv/…`) | ✅ |
| 2 | I378-A02 | Bilingual KissKH title (local - English) gets `ids.tmdb` after enrich | ✅ |
| 3 | I378-A03 | Manual: Sources on a matched drama film shows non-KissKH Forja rows | ⬜ |

---

## Summary

Enrich still wrote `ids.tmdb` / `imdb` for many titles, but extract kept `resolveType: drama`. Dual movie/TV scrapers treat any non-`movie` type as TV (`/tv/{id}/1/1`), so films (e.g. TMDB movie `1032863`) returned empty while KissKH (kisskhId) still worked. Separately, KissKH bilingual titles failed TMDB multi-search until the hub stripped the English alt / season subtitle for match.

**Root fix:** pack stamps movie/tv resolveType; enrich syncs it; host remaps cached `drama` metas. Asian Drama pack **1.0.40**.

### Related

- [asian-drama](../../features/hubs/asian-drama.md)
- [369](369-[fixed]-kisskh-home-movie-title-match.md) (KissKh Search scoring on Home)
