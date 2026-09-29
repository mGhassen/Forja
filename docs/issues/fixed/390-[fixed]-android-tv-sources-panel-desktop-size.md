# 390 — Android TV Sources panel stays desktop-sized

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Player · Sources · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I390-T01 | Treat 1080p@xhdpi (960×540) and 16:9 720p panels as TV when leanback did not answer | ✅ |
| 2 | I390-T02 | Sources overlay keeps leanback density; panel width stays the TV side width under the phone cutoff | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I390-A01 | Android TV: open Sources while playing — panel is the leanback side width (kind tabs, chips, search, rows), not the desktop 480-wide sheet | ⬜ |

---

## Summary

On Android TV the in-player Sources panel painted at desktop size: wide sheet, desktop type. 1080p at xhdpi is a 960×540 logical panel, which missed the old “shortest side ≥ 600” TV check when the leanback channel did not answer. A TV under 700 logical px also took the phone 92% sheet instead of the leanback side width.
