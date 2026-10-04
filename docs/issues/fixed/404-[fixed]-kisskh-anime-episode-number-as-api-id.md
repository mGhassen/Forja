# 404 — KissKh Anime: episode number treated as Episode API id

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/kisskh.js` · Anime Sources · KissKh

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I404-T01 | Ignore `episodeVideoId` unless Asian Drama also injects `kisskhId` (`dramaId`) | ✅ |
| 2 | I404-T02 | Title-search path uses `mappedEpisode` when picking the KissKh episode | ✅ |
| 3 | I404-T03 | Fix `hasKkey` start log (operator precedence) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I404-A01 | Anime → Black Clover E1 → KissKh lists a playable stream (title pick → drama 1261) | ⬜ |

---

## Summary

Anime MetaVideo ids are episode numbers (`"1"`, `"2"`, …). Host injects them as `episodeVideoId`. KissKh’s `ctxConfigMap` maps that to `episodeId`, so extract short-circuited to `/api/DramaList/Episode/1` (HTTP 400 on every mirror) and never title-searched — even though KissKh has `Black Clover (TV)` as drama `1261`.

**Root fix:** only treat `episodeId` as a KissKh Episode API id when `dramaId` / `kisskhId` is also present (Asian Drama hub). Otherwise title-search. Providers pack **1.6.27**.

### Related

- [369](369-[fixed]-kisskh-home-movie-title-match.md) — Home title-score Search
