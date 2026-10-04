# 410 — AniDao Sources empty (site moved to anidao.es)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/anidao.js` · Anime Sources · AniDao

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 1 / 1** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I410-T01 | Point AniDao at `https://anidao.es` and scrape the live WP / AniWaves search + watch + 1anime stream URLs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I410-A01 | Anime → a title that exists on AniDao → AniDao lists a playable stream | ⬜ |

---

## Summary

`anidao.to` returns HTTP 522. The site is live at [anidao.es](https://anidao.es/). Catalog/search/watch HTML is the AniWaves WordPress theme (`/wp-json/v1/aniwaves/search/suggestions`, `/watch/{slug}/ep-N`, `data-link-id` base64 embeds). HD-1 embeds `my.1anime.site/play/{id}` → playable `…/stream/{id}` (Referer required).

**Root fix:** `SPECS.base` is `https://anidao.es`. Extract uses the live search/watch/stream paths. Providers pack **1.6.37**.
