# 014 — IPTV Reddit catalog cursor infinite loop

**Priority:** P1 (when hit)  
**Severity:** High  
**Status:** fixed (2026-07-06) — **complete** (root cause fixed, not symptom-only)  
**Area:** `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart`, `iptv_controller.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[fixed]-sync-ffi-ui-thread-audit.md)
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** |
| **Backlog** | [0.4.5](../backlog/done/0.4.5-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I14-F01 | IPTV Reddit catalog cursor loop fixed | ✅ |

---



## Root cause (before fix)

`scrapeCatalogPage` stripped `reddit:` prefix before `_scrapeRedditCatalog`. Cursor `reddit:1:` parsed as subreddit **0** instead of **1** → infinite retry on `IPTV_ZONENEW`.

## Fix (done — 2026-07-06)

1. **`parseRedditCatalogCursor()`** — `iptv_network.dart:499`; used at `:728`. Formats: `reddit:<subIdx>:<token>`, legacy `reddit:<token>`, bare token.
2. **Full cursor passthrough** — `scrapeCatalogPage` passes `after` unchanged to `_scrapeRedditCatalog`.
3. **Early exit** — after 4 consecutive empty Reddit pages (`catalogSubCount`), stop — `iptv_controller.dart:316`.
4. **Cancel** — `stopScrape()` / `_scrapeCancel` — `iptv_controller.dart:255`.
5. **Tests** — `apps/forja/test/iptv_catalog_cursor_test.dart` (4 tests pass).

**Verify:** `flutter test apps/forja/test/iptv_catalog_cursor_test.dart`

## If this file is deleted

Regression risk: cursor format spec lost. Tests in repo remain but spec should stay documented. Re-run cursor tests if pagination changes.
