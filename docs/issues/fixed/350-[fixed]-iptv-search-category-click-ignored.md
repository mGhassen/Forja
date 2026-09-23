# 350 — IPTV search ignores category click

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV Live · search · category rail · catalog_page

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I350-T01 | Pack feed: stop clearing `categoryId` when `q` is set | ✅ |
| 2 | I350-T02 | Host: mid-search category pick stays selected; empty search skips peek land | ✅ |
| 3 | I350-T03 | Category rail: do not auto-land first group while searching | ✅ |
| 4 | I350-T04 | Unit tests (Dart filter + effective category; Rust q+category) + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I350-A01 | Unit: `filterSort` / `iptvEffectiveCategoryId` / Rust page q+category | ✅ |
| 2 | I350-A02 | App: search “4k” → shelf-wide hits; click a category → only that group’s matches | ⬜ |
| 3 | I350-A03 | App: clear search restores prior category when none was picked mid-search | ⬜ |

---

## Summary

**Symptom:** Typing IPTV Search showed matching channels across the catalog, but tapping a category in the rail only focused/highlighted the row — the grid kept shelf-wide results.

**Root cause:** Host correctly clears category on search start (shelf-wide + `hitCategoryIds`). The IPTV pack then always blanked `categoryId` whenever `q` was set, so a mid-search category pick never reached `catalog_page`. The rail also forced empty selection while searching and could peek last-land over an empty search selection.

**Fix:** Pass `categoryId` + `q` together when the user picks a category mid-search; keep shelf-wide when search is active and no category is selected; paint the mid-search pick on the rail.

---

## Related

- [315](315-[fixed]-iptv-search-no-categories.md) — search hit categories on the rail
- [290](../290-[open]-iptv-catalog-page-host-shelf.md) — paged catalog_page shelf
