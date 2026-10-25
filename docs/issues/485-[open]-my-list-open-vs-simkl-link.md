# 485 — My List Open with ≠ Simkl link

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** My List · Open with · Simkl  
**Reported:** 2026-10-25 (hub open Afflem Arabic vs Home Latin TMDB for Simkl)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Open with binds hub open and TMDB from the same checked hit. A title opened in Afflem (Arabic) cannot keep that open while linking Simkl to a Home/TMDB match under a Latin name. My List cards never show whether Simkl is linked.

## Root cause (hypothesis until verified in code)

`persistListOpenBinding` / `ListOpenBinding.persistBinding` write `pluginId`+`open` from the hit and derive `tmdbId` from that same meta. No separate Simkl-link writer. Open-with never calls `SimklService.setListStatus`.

**Placement:** My List pack emits `trackerMark` / `trackerLink` on feed paint; host only paints pack props + generic TMDB attach persist. Do not invent Simkl chrome in host `paint_artifact`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I485-T01 | `persistSimklTmdbLink` + preserve `tmdbId` on open bind + stamp tmdb fields + Simkl push | ✅ |
| 2 | I485-T02 | Bind sheet: Open with vs Simkl modes (S header + Open with button) | ✅ |
| 3 | I485-T03 | PosterCard `subtitleTrailing` + My List Simkl S mark when logged in | ✅ |
| 4 | I485-T04 | Feature + changelog copy | ✅ |
| 5 | I485-T05 | Unit tests for persist split / stamp | ✅ |
| 6 | I485-T06 | Bind sheet D-pad: chips ↔ Match / Open with icons | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I485-A01 | Open with Afflem keeps Afflem open when linking Home TMDB for Simkl | ⬜ |
| 2 | I485-A02 | My List card shows S ok when `tmdbId` set and Simkl logged in; S+cross when not linked | ⬜ |
| 3 | I485-A03 | Simkl chrome hidden when Simkl logged out | ⬜ |
| 4 | I485-A04 | After Simkl link, status appears on Simkl for that TMDB id | ⬜ |

## Links

- [RFC-108](../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md)
- [RFC-059](../rfc/fixed/059-[fixed]-hub-list-follow.md)
- [my-list](../features/movies-tv/my-list.md)
- [simkl](../features/accounts/simkl.md)
