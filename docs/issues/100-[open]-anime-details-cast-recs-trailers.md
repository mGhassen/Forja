# 100 — Anime details Characters / Staff / Trailers / More Like This

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** anime / details

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 6** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I100-T01 | Slim list `_mediaFields` (no trailer / streamingEpisodes) | ✅ |
| 2 | I100-T02 | `getCharacters` / `getStaff` / `getRecommendations` as separate AniList calls | ✅ |
| 3 | I100-T03 | Trailer from details payload; `MediaDetailsTrailersSection` on anime details | ✅ |
| 4 | I100-T04 | Lazy season episodes — `getEpisodes` only after opened season’s `getDetails` | ✅ |
| 5 | I100-T05 | Wire Characters / Staff / Trailers / More Like This / Related rows | ✅ |
| 6 | I100-T06 | Manual QA — rows populate; season switch reloads; no list-query bloat | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I100-A01 | Anime details shows Characters + Staff (when AniList has them) | ⬜ |
| 2 | I100-A02 | YouTube trailer row opens trailer player when AniList has a trailer | ⬜ |
| 3 | I100-A03 | More Like This shows AniList recommendations (not franchise Related) | ⬜ |
| 4 | I100-A04 | Switching seasons reloads rows for that AniList id; episodes only for opened season | ⬜ |

---

## Summary

Anime details previously only had hero + episodes + Related. Characters, staff, trailers, and recommendations come from separate AniList queries (not one mega `Media` query). List/catalog queries stay lean — trailer and `streamingEpisodes` are details-only. Episode rails for a season load only after that season is opened and its details return.
