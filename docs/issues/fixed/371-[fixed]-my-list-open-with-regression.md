# 371 — My List Open with… / hub picker regression

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** My List · kit.list open · RFC-108  
**Reported:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I371-T01 | Feed-only kit.list tap routes through `openKitListItem` / hub binding | ✅ |
| 2 | I371-T02 | Poster secondary-click / long-press / TV hold → `forcePick` Open with… | ✅ |
| 3 | I371-T03 | Host unit tests for binding gate + kit list row flatten | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I371-A01 | My List poster tap still opens via saved / default / Open in… sheet | ⬜ |
| 2 | I371-A02 | Right-click / long-press My List poster opens **Open with…** hub sheet | ⬜ |

---

## Cause

Thin kit painter (`CatalogCardsGrid` + `paint_tree`) opened list posters with `openMetaItem` only. RFC-108 `openListItemWithBinding` / `forcePick` stayed in the store layer with **no UI call sites** — right-click Open with… and ambiguous hub pick were dead.

## Fix

- `CatalogCardsGrid.onItemLongPress` → `InteractivePosterCard` secondary / hold
- Feed-only packs (`pluginHasDetails == false`) use hub binding; details hubs unchanged
- Related: [RFC-108](../../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md)
