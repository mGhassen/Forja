# Issue 315: IPTV search shows channels but “No categories”

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · search · category rail · catalog_page

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |
| **Current slice** | Paged-search category hits |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I315-T01 | Host paint: vodPaged search fills `searchHitKindIds` (stop clearing hits) | ✅ |
| 2 | I315-T02 | catalog_page: when `q` set, return `hitCategoryIds` + filter `categories` | ✅ |
| 3 | I315-T03 | IPTV pack feed publishes `hitCategoryIds`; host applies to category rail | ✅ |
| 4 | I315-T04 | Rust unit test for search category filter | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I315-A01 | IPTV Live search (e.g. “m6”) shows matching channel cards **and** their categories in the rail | ⬜ |

---

## Summary

**Symptom:** Typing in IPTV Search filled the channel grid but the category rail showed **No categories**.

**Root cause:** After issue 290, Live/Movies/Series search re-queries `catalog_page` with `q` (not paint-filter). The category rail still filters via `searchHitKindIds`, which the paint-only path used to fill. The vodPaged branch **cleared** that set, so the rail kept only label matches — useless for channel-name queries like “m6”.

**Fix:** Populate `searchHitKindIds` from the current page’s channel kinds while searching; shelf-wide `hitCategoryIds` from Rust `catalog_page` so categories beyond page 1 still appear.
