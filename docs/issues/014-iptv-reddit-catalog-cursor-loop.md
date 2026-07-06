# 014 — IPTV Reddit catalog cursor infinite loop

**Priority:** P1 (when hit)  
**Severity:** High  
**Status:** fixed (2026-07-06)  
**Area:** `apps/forja/lib/features/iptv/iptv/data/iptv_network.dart`  
**Reported:** 2026-07-06  
**Parent:** [004](004-sync-ffi-ui-thread-audit.md)

## Summary

When Reddit OAuth and RSS both failed, catalog cursor `reddit:1:` was parsed as subreddit **0** instead of **1**. Scraper retried `IPTV_ZONENEW` forever. Combined with sync FFI ([004](004-sync-ffi-ui-thread-audit.md)), app appeared permanently stuck.

## Root cause

`scrapeCatalogPage` stripped `reddit:` prefix before `_scrapeRedditCatalog`, breaking `reddit:<subIdx>:<token>` parsing.

## Fix

- `parseRedditCatalogCursor()` helper
- Pass full cursor through to `_scrapeRedditCatalog`
- Unit tests in `apps/forja/test/iptv_catalog_cursor_test.dart`
- Early exit after 4 empty Reddit pages in `_scrapeAndVerify`
- Scrape Stop button

## Retained for

Regression reference. If catalog pagination changes, re-run cursor tests.
