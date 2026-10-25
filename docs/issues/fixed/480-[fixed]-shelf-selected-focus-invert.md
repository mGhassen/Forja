# Issue 480: IPTV / Live Sports shelf — selected + focus invert missing

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** foundation · WidgetShelf · IPTV / Live Sports chrome  
**Reported:** 2026-10-25 (manual — selected shelf tab looked the same when focused)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I480-T01 | Restore `invert = selected && paintActive` (white fill + accent ink) in `WidgetShelf` | ✅ |
| 2 | I480-T02 | Changelog 2.0.x draft bullet | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I480-A01 | Manual: IPTV Live/Movies/Series and Live Sports Sports/TV — focus/hover the selected tab → white fill + accent label | ⬜ |

---

## Summary

**Symptom:** Focusing or hovering the already-selected shelf tab (IPTV Live/Movies/Series, Live Sports Sports/TV) kept the gradient + white ink — no reverse color cue.

**Root cause:** `25f7cd686` removed invert in `packages/forja_foundation/lib/widgets/chrome/widget_shelf.dart` (Series green ink looked brand-colored). Selected and selected+focused painted the same.

**Root fix:** Reintroduce invert for selected + hover/focus; reload chip uses accent ink while inverted.

**Note:** Literal `v1.4.0` host shelf never had invert; the reverse look lived in mid-1.5 `WidgetShelf` before that removal.
