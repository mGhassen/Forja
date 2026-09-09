# 266 — Android TV IPTV ↑ from catalog after Movies/Series shelf change

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** IPTV · Android TV · catalog D-pad · `iptv_tv_focus` / browser view

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I266-T01 | `iptvFocusTopBarFromCatalog` — shelf then Portals, retry across frames | ✅ |
| 2 | I266-T02 | On shelf/portal+section change: reset stream D-pad memory + jump stream scroll to 0 | ✅ |
| 3 | I266-T03 | Wire category/stream ↑ + land retry; feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I266-A01 | Manual ATV: Movies mid-grid → Series shelf → category → → first tile → ↑ lands on Series (or Portals from right column) | ⬜ |
| 2 | I266-A02 | Manual ATV: Series → Movies (same numeric category id) → → → ↑ reaches Movies shelf | ⬜ |

---

## Summary

**Symptom:** On Android TV IPTV **Movies** / **Series**, after switching Live/Movies/Series shelves, ↑ from the catalog sometimes did not reach the top-bar shelf tabs or **Portals**.

**Root cause:**

1. Stream grid kept the previous shelf’s `lastFocusedIndex` and scroll offset. Movies/Series often share numeric category ids (`"1"`), so → into streams skipped the memory reset (`prev == categoryId`) and landed mid-grid — ↑ only walked tiles, never the first-row chrome edge.
2. Catalog ↑ edges call `iptvFocusRowItem` once and always consume the key; a one-frame miss after remount left focus stuck.

**Fix:** Reset stream focus memory + scroll on shelf change; ↑ uses `iptvFocusTopBarFromCatalog` (shelf → Portals, multi-frame retry); category land retries after remount.
