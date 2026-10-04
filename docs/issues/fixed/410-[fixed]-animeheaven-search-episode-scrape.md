# 410 — AnimeHeaven Sources empty (search/episode scrape)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/animeheaven.js` · Anime Sources · AnimeHeaven

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I410-T01 | Parse `fastsearch.php` rows with single-quoted `href` / `fastname` | ✅ |
| 2 | I410-T02 | Parse episode keys from `gatea( "id")` and `class= ' watch2 '` | ✅ |
| 3 | I410-T03 | Skip gate fallback `<source>` URLs that include `&error` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I410-A01 | Anime → One Piece E1 → AnimeHeaven lists a playable stream | ⬜ |

---

## Summary

AnimeHeaven.me still serves search, series, and gate pages, but markup uses single quotes and `gatea( "id")` with a space after `(`. Extract required `href="…"` and `gatea("id")` with `class="watch2"`, so search fell back without titles and episode scrape returned nothing.

**Root fix:** quote-tolerant search + `gatea` / `watch2` episode scrape. Providers pack **1.6.35**.
