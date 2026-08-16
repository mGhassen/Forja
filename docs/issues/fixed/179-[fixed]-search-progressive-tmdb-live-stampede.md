# 179 — Search: TMDB blocked by Stremio live catalog stampede

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Search · Stremio catalogs

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **4 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I179-T01 | Progressive search: emit TMDB sections before Stremio catalogs finish | ✅ |
| 2 | I179-T02 | Exclude live / sport / `*live*` catalogs from global Search (VOD only) | ✅ |
| 3 | I179-T03 | Stale-query generation: ignore in-flight results after query changes | ✅ |
| 4 | I179-T04 | `getCatalog`: no retry on HTTP 429 + host cooldown (same idea as streams) | ✅ |
| 5 | I179-T05 | Infer live feature for live-named `tv` catalogs; unit tests | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I179-A01 | Typing a title shows TMDB cards before flixnest/other addons return | ✅ |
| 2 | I179-A02 | Global Search does not request `essential-live-events` / `dlstreams-live` | ✅ |
| 3 | I179-A03 | Mid-type query change does not apply stale partial results | ✅ |
| 4 | I179-A04 | Catalog 429 is not retried; host is cooled down briefly | ✅ |

---

## Summary

Search used one `FutureProvider` that awaited TMDB **then** `Future.wait` on every searchable VOD-flagged Stremio catalog. Live addons like flixnest (`type: tv`, ids `*-live*`) were inferred as VOD, got searched on every debounce pause, returned HTTP 429, and blocked the UI from showing TMDB hits already in hand.

**Root fix:** progressive `SearchResultsNotifier` (TMDB first, addon sections as catalogs finish), live-catalog exclusion from Search via `StremioAddonFeatures.catalogLooksLive`, generation cancel on query change, catalog 429 no-retry + host cooldown, live inference for live-named `tv` catalogs.

**Verify:** Search a title with flixnest installed → TMDB cards appear quickly; logs must not show `essential-live-events` / `dlstreams-live` search URLs.
