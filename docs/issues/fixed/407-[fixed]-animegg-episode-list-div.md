# 407 — AnimeGG Sources empty (episode list scrape)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/animegg.js` · Anime Sources · AnimeGG

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I407-T01 | Parse series episode links from `anm_det_pop` anchors (pages use `div`, not `li`) | ✅ |
| 2 | I407-T02 | Search titles from `h2`; exact title match before substring | ✅ |
| 3 | I407-T03 | Compare mapped episode as a number | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I407-A01 | Anime → Naruto E1 → AnimeGG lists a playable Sub and/or Dub stream | ⬜ |

---

## Summary

AnimeGG series pages list episodes in `div` rows with `href` before `class="anm_det_pop"`. Extract still walked `<li>` and required `class` before `href`, so every title returned zero episodes. Search titles are in `h2`, not `strong`.

**Root fix:** scrape `anm_det_pop` anchors, `h2` search titles, numeric episode compare. Providers pack **1.6.32**.
