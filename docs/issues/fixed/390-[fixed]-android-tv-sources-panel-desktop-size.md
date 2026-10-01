# 390 — Android TV Sources panel stays desktop-sized

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Player · Sources · Android TV

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I390-T01 | Treat 1080p@xhdpi (960×540) and 16:9 720p panels as TV when leanback did not answer | ✅ |
| 2 | I390-T02 | Sources overlay keeps leanback density; panel width stays the TV side width under the phone cutoff | ✅ |
| 3 | I390-T03 | Source cards, titles, badges, and provider status use leanback type even when the ancestor shell metrics are still desktop | ✅ |
| 4 | I390-T04 | Stream-card title and status type sit under the body ladder; the colored status stripe is 1px on TV | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I390-A01 | Android TV: open Sources — panel is the leanback side width, and each stream card (title, badges, provider status) uses leanback type, not the desktop 13px row | ⬜ |

---

## Summary

On Android TV the in-player Sources panel painted at desktop size: wide sheet, desktop type. 1080p at xhdpi is a 960×540 logical panel, which missed the old “shortest side ≥ 600” TV check when the leanback channel did not answer. A TV under 700 logical px also took the phone 92% sheet instead of the leanback side width.

The side width could already be leanback while the stream cards still read desktop shell metrics: title, quality badges, and the provider status stayed at the 13px row.
