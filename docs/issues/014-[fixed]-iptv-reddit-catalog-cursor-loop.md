# 014 — IPTV Reddit catalog cursor infinite loop

**Priority:** P1 (when hit)  
**Severity:** High  
**Status:** fixed (2026-07-06)  
**Area:** `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md)

## Summary

When Reddit OAuth and RSS both failed, catalog cursor `reddit:1:` was parsed as subreddit **0** instead of **1**. Scraper retried `IPTV_ZONENEW` forever. Combined with sync FFI ([004](004-[open]-sync-ffi-ui-thread-audit.md)), app appeared permanently stuck.

## Root cause

`scrapeCatalogPage` stripped `reddit:` prefix before `_scrapeRedditCatalog`, breaking `reddit:<subIdx>:<token>` parsing.

## Solution (2026-07-06)

### 1. Cursor parsing — `parseRedditCatalogCursor()`

Added in `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart`. Decodes cursors produced by `_scrapeRedditCatalog`:

| Format | Meaning |
|--------|---------|
| `reddit:<subIdx>:<token>` | Current — subreddit index + pagination token |
| `reddit:<token>` | Legacy — sub 0 |
| `<token>` | Legacy bare token — sub 0 |

Returns `RedditCatalogCursor(subIdx, after)`.

**Bug:** `scrapeCatalogPage` previously stripped the `reddit:` prefix before calling `_scrapeRedditCatalog`, so `reddit:1:` was parsed as sub **0** instead of **1**, causing an infinite retry on `IPTV_ZONENEW`.

**Fix:** Pass the full cursor string through unchanged; `_scrapeRedditCatalog` calls `parseRedditCatalogCursor(after)`.

### 2. Early exit — `_scrapeAndVerify` in `iptv_controller.dart`

After `catalogSubCount` (4) consecutive empty Reddit pages — one full cycle through all subreddits with zero portals — set `exhausted = true` and stop fetching.

### 3. Cancel — `stopScrape()`

`_scrapeCancel` flag checked in the scrape loop. UI Stop button calls `stopScrape()` and sets status to `Stopped.`.

### 4. Tests

`apps/forja/test/iptv_catalog_cursor_test.dart` — sub index, pagination token, legacy formats.

### Combined effect

With sync FFI also offloaded ([004](004-[open]-sync-ffi-ui-thread-audit.md)), the app no longer appears permanently stuck when Reddit OAuth and RSS both fail.

## Retained for

Regression reference. If catalog pagination changes, re-run cursor tests.
