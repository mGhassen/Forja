# 098 — Anime details season chain (AniList PREQUEL/SEQUEL)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** anime / details

## Status at a glance

| | |
|--|--|
| **Progress** | **18 / 19** |

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
| 7 | I98-T07 | Walk MOVIE as season-chain bridge (emit TV only) — Youjo Senki S1→Movie→S2 | ✅ |
| 8 | I98-T08 | Port season BFS into anime pack `anilist.js` after AnimeService cutover | ✅ |
| 9 | I98-T09 | Emit `details.data.seasons` (`number` / opaque `id` / `selected`) | ✅ |
| 10 | I98-T10 | Host `parseKitDetailSeasons` + season chip reloads Media by opaque id | ✅ |
| 11 | I98-T11 | Related excludes chain ids; relation type on `meta.badge` | ✅ |
| 12 | I98-T12 | Foundation + kitPosterBadge tests for seasons parse / Side Story badge | ✅ |
| 13 | I98-T13 | Stop TMDB enrich padding anime videos to franchise episodeCount; cour-scoped facts | ✅ |
| 14 | I98-T14 | Miruro-style season labels (Season/OVA/Part + year) + SIDE_STORY OVAs in rail | ✅ |
| 15 | I98-T15 | Walk OVA bridges (Slime Coleus); cap videos at Media.episodes vs absolute stream titles | ✅ |
| 16 | I98-T16 | Season chip switch: stub params + forceRefresh; no prior-cour merge; hero season subtitle | ✅ |
| 17 | I98-T17 | TMDB enrich fills anime episode stills for selected Season N without padding the list | ✅ |
| 18 | I98-T18 | Sources footer / play loading use franchise chip season for labels; extract stays media-local S1 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I98-A01 | Multi-season anime shows Season 1…N rail; picking a season reloads that AniList entry | ⬜ |
| 2 | I98-A02 | Single-season / movie entries stay seasonCount 1 (no empty rail) | ⬜ |
| 3 | I98-A03 | Watched marks and Resume stay correct after switching seasons (per AniList id) | ⬜ |
| 4 | I98-A04 | Seasons in the chain do not also appear under Related | ⬜ |
| 5 | I98-A05 | One Piece details shows Related films/specials with Side Story / Summary badges; no MONSTERS fake season | ⬜ |
| 6 | I98-A06 | Youjo Senki details shows Season 1 + Season 2; Movie stays under Related (not a season chip) | ⬜ |

---

## Summary

AniList stores each cour as a separate Media id. Catalog cards stay that way; details walk the PREQUEL→SEQUEL spine in the **anime pack** and emit `data.seasons` so the host shows Season 1…N and reloads that Media (hero, eps, progress, watched). Watched keys stay `S1` per AniList id.

Continuous series (One Piece) are one Media — no arc seasons in AniList. Franchise films/specials come from typed `relations` edges under **Related** (relation badges; chain siblings excluded).

Some franchises put a **MOVIE** between TV cours (Youjo Senki S1 → Movie → S2). The pack walks those movies as bridges but only emits TV / TV_SHORT / multi-ep ONA into the season rail.

**Regression note:** T01–T04 / T06–T07 were the pre-cutover Dart `AnimeService` path (deleted with pack migration). T08–T12 restore the same behavior in pack + generic host.
