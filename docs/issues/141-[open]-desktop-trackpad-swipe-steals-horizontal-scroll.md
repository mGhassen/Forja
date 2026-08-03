# 141 — Desktop trackpad swipe-back steals horizontal scroll

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/navigation/` — desktop trackpad Back gesture

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I141-T01 | Progressive trackpad back (progress 0..1) — commit only when fully filled | ✅ |
| 2 | I141-T02 | Suppress nav gesture over horizontal scrollables (rows, addons, filters, hero) | ✅ |
| 3 | I141-T03 | Left-edge browser-style arrow indicator tied to progress | ✅ |
| 4 | I141-T04 | Stop macOS native AppKit swipe from instant `trackpadBack` pop | ✅ |
| 5 | I141-T05 | Block swipe-back over Sources panel / chip strips / HorizontalScroller (`DesktopSwipeBackIgnore`); horizontal viewports even when not overflowing | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I141-A01 | Desktop: two-finger horizontal pan over Nuvio addons / catalog rows scrolls the strip — does not pop details | ⬜ |
| 2 | I141-A02 | Desktop: two-finger swipe-right on page chrome shows left edge arrow; full fill pops; release early dismisses | ⬜ |

---

## Summary

`BackNavigationScope` used a global `PointerPanZoom` route and popped on any strong horizontal pan (`|dx| >= 90`), intentionally bypassing scrollables. Scrolling torrent-portal Nuvio addons, catalog rows, and similar strips triggered **previous page**.

**Root fix:** browser-style progressive edge arrow — arm only when not over a horizontal scrollable / ignored panel; commit Back only at 100% fill. Native macOS `swipe` no longer instant-pops.

**Follow-up (T05):** first suppress only matched overflowing horizontal viewports, so short chip rows (`maxScrollExtent == 0`) and panel chrome still armed Back. Now [DesktopSwipeBackIgnore] wraps Sources panel + chip strips + [HorizontalScroller], and any horizontal viewport blocks regardless of overflow.
