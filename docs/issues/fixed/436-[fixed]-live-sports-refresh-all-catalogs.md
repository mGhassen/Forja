# 436 — Live Sports Refresh reloads every catalog when one is selected

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · progressive schedule · Catalog chip · Refresh

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 7 / 7** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I436-T01 | Progressive `forceRefresh` invalidates only the selected catalog cache key (not whole `live_sports.feed`) | ✅ |
| 2 | I436-T02 | `packChromeFeedParams` always stamps `catalogFilter` from Catalog chip (wins over load-param `all`) | ✅ |
| 3 | I436-T03 | Skip full hub `_loadPage` on Refresh when progressive live feed is visible | ✅ |
| 4 | I436-T04 | Unique `PackLoadedPaint` keys per list id (Sports/TV no shared state) | ✅ |
| 5 | I436-T05 | Pack scoped cache clear + wider 24/7 always-on detection | ✅ |
| 6 | I436-T06 | Channel card paint only on TV shelf; Sports match lists ignore channel heuristic | ✅ |
| 7 | I436-T07 | Sports↔TV showWhen remount seeds refreshEpoch — no force re-scrape of warm catalogs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I436-A01 | Pick Catalog streamfree → Refresh → only `Loading streamfree… 1/1` (not 1/N through every pack) | ⬜ |

---

## Summary

After the Sports/TV shelf, **Refresh** with a Catalog chip selected re-scraped every live pack (`Loading … 1/N`). Causes: whole-namespace cache wipe on force, Catalog chip filter losing to load-param / empty → `all`, and Refresh also running full hub `_loadPage`.

**Root fix:** scoped invalidate + chip always stamps `catalogFilter` + progressive Refresh skips layout remount + separate list paint keys. Pack cache clear matches. Channel-style rows (no kickoff, no teams, no “vs”) go to **TV**.

**Related:** [434](434-[fixed]-live-sports-sports-tv-shelf.md) · [435](435-[fixed]-live-sports-rescrape-on-tab-return.md) · feature [live-sports](../../features/live/live-sports.md)
