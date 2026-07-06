# 014 — IPTV Reddit catalog cursor infinite loop

**Priority:** P1 (when hit)  
**Severity:** High  
**Status:** fixed (2026-07-06) — **complete** (root cause fixed, not symptom-only)  
**Area:** `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart`, `iptv_controller.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Status summary

| Layer | Status | Notes |
|-------|--------|-------|
| **Root cause** — cursor parsing bug → infinite loop | **fixed** | logic fix, not isolate offload |
| **Safety net** — empty-page exit, Stop button | **fixed** | `iptv_controller.dart` |
| **UI freeze during scrape** | **fixed** (separate) | isolate offload — [004](004-[open]-sync-ffi-ui-thread-audit.md) |

No open engine debt for this issue. This is a **real fix**, not a workaround.

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
