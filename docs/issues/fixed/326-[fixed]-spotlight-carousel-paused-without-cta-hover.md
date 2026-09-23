# 326 — Spotlight carousel stays paused without View details hover

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Desktop · Home / hub cinematic hero auto-advance

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I326-T01 | `CinematicHero`: pause on CTA focus only when TV or keyboard highlight — not mouse-retained focus | ✅ |
| 2 | I326-T02 | Widget test: desktop touch-highlight focus + hover leave resumes auto-advance | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I326-A01 | Desktop Home: leave **View details** / pin with the pointer — carousel fills and advances again (pause icon clears) even if the button still has mouse focus | ✅ |
| 2 | I326-A02 | Android TV: D-pad land on **View details** still pauses until leave | ⬜ |

---

## Summary

Spotlight auto-advance paused while **View details** / the list pin was hovered **or** focused. On desktop, clicking or otherwise retaining focus on the CTA left focus without hover chrome (`ShellKeyboardFocusScope` hides the ring in pointer mode), so the pause icon stuck after the pointer left.

**Root fix:** engagement uses cached `ShellPaintScope` flags — hover always pauses; focus pauses on leanback TV, or on desktop only while `FocusHighlightMode.traditional` (keyboard). Mouse-retained focus no longer freezes the carousel.
