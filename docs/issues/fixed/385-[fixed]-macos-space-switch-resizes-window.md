# 385 — macOS: moving the window to another desktop resizes it

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop / macOS / window chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** tasks · **0/1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I385-T01 | Ignore AppKit `zoom` on Space/display moves; keep the last user point size | ✅ |
| 2 | I385-T02 | Changelog + platforms note | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I385-A01 | macOS: move the window to another desktop — width and height stay; green-button zoom still fills and restores | ⬜ |

---

## Summary

Dragging Forja to another Space (or another display) changed its size. AppKit calls `zoom` and `setFrame` on that move. The green-button override treated the extra `zoom` as a user toggle, and the new frame replaced the size the user had.

**Root fix:** `MainFlutterWindow` only toggles fill for the green button, a title-bar double-click, or `window_manager`. For a short time after a Space or display change, other frame changes keep the last user point size (clamped when the destination work area is smaller). Picture-in-picture and fullscreen still set the frame themselves.

## Related

- `apps/forja/macos/Runner/MainFlutterWindow.swift`
- [284](284-[fixed]-macos-27-window-zoom-snap-back.md)
