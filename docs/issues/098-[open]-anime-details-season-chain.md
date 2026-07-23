# 098 — Anime details season chain (AniList PREQUEL/SEQUEL)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** anime / details

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 7** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I98-T01 | Wire `AnimeService.getSeasons` into anime details | ✅ |
| 2 | I98-T02 | Season rail on details switches Media (hero, eps, progress, watched) | ✅ |
| 3 | I98-T03 | Keep watched/progress keys `S1` per AniList id (`watchedSeasonForKeys`) | ✅ |
| 4 | I98-T04 | Exclude chain siblings from Related | ✅ |
| 5 | I98-T05 | Manual QA — multi-season title season switch + resume/watched | ⬜ |
| 6 | I98-T06 | Typed AniList relations rail (films/specials) + skip 1-ep ONA season pollution | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I98-A01 | Multi-season anime shows Season 1…N rail; picking a season reloads that AniList entry | ⬜ |
| 2 | I98-A02 | Single-season / movie entries stay seasonCount 1 (no empty rail) | ⬜ |
| 3 | I98-A03 | Watched marks and Resume stay correct after switching seasons (per AniList id) | ⬜ |
| 4 | I98-A04 | Seasons in the chain do not also appear under Related | ⬜ |
| 5 | I98-A05 | One Piece details shows Related films/specials with Side Story / Summary badges; no MONSTERS fake season | ⬜ |

---

## Summary

AniList stores each cour as a separate Media id. Catalog cards stay that way; details now walk the existing PREQUEL→SEQUEL spine (`getSeasons`) so related seasons share one details page with a season switcher.

Continuous series (One Piece) are one Media — no arc seasons in AniList. Franchise films/specials come from typed `relations` edges and show under **Related**.
