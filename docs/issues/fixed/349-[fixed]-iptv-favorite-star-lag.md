# 349 — IPTV favorite star lags on click

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** IPTV Live · channel star · Portals panel star · `CategoryBarActionHost`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I349-T01 | Channel star: optimistic paint + patch `cachedLiveListParams` before prefs I/O | ✅ |
| 2 | I349-T02 | Prefer cached `portalStoreKey` (skip vault parse); Portals panel optimistic row flip | ✅ |
| 3 | I349-T03 | Unit + changelog + feature note | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I349-A01 | Unit: cache patch + resolveLiveStoreKey prefer portalStoreKey | ✅ |
| 2 | I349-A02 | App: star a Live channel — icon flips on the same tap (no wait for vault/prefs) | ⬜ |

---

## Summary

Tapping the Live channel favorite star awaited vault portal resolve, SharedPreferences load/save, then a full `liveListFeedParams()` reload **before** `setState`. The icon lagged. Pin already painted optimistically; star did not.

### Fix

- Flip the star immediately; patch favorites in the sync cache; persist prefs in the background
- Reuse cached `portalStoreKey` instead of re-parsing the portal vault on every toggle
- Portals panel favorite star updates inventory paint before vault round-trip

### Related

- [282](../282-[open]-iptv-catalog-category-rail-restore.md)  
- [iptv-xtream](../../features/live/iptv-xtream.md)
