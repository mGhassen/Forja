# 533 — TMDB season card posters missing

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Home · details · seasons  
**Reported:** 2026-11-04 (manual — season cards blank / same show poster; hero never swaps)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Home TMDB series details, season cards do not show per-season poster art (all fallback / empty). Selecting a season does not update the hero backdrop to that season’s poster (docs claim it does).

## Root cause

1. `hubs/home/tmdb.js` `tmdbDetails` never emitted `data.seasonPosters` from TMDB `seasons[].poster_path`.
2. Host only passed `seasonPosters` into `TvSeasonEpisodePicker` for franchise `data.seasons` (`_usesPackSeasons`); TMDB video-derived seasons used `const {}`.
3. Non-pack `onSeasonSelected` never updated `_heroBackdrops`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I533-T01 | Home pack emit absolute `data.seasonPosters` from TMDB seasons | ✅ |
| 2 | I533-T02 | Foundation parse `data.seasonPosters`; host wire cards + hero swap | ✅ |
| 3 | I533-T03 | Unit test parse; changelog | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I533-A01 | Multi-season TMDB show: season cards show distinct season posters | ⬜ |
| 2 | I533-A02 | Selecting a season crossfades hero to that season poster (show backdrop if missing) | ⬜ |

## Links

- [TMDB details](../../features/movies-tv/tmdb-details.md)
