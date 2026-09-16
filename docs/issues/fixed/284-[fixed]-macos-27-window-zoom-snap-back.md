# 284 — macOS 27: window-bar zoom fills then snaps back

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop / macOS / window chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I284-T01 | Override `NSWindow.zoom` to fill/restore `visibleFrame` (hidden titlebar) | ✅ |
| 2 | I284-T02 | Clear aspect/max on boot; schema-bump drop corrupt geometry prefs; settle save | ✅ |
| 3 | I284-T03 | Changelog + platforms note | ✅ |
| 4 | I284-T04 | Zoom reentrancy gate + async re-assert; reject tall-narrow snap saves; boot at work-area size (no small→fill flash) | ✅ |
| 5 | I284-T05 | Animate fill/restore (`setFrame` animate + gate covers duration) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I284-A01 | macOS 27: double-click title bar / green zoom fills work area and stays | ⬜ |
| 2 | I284-A02 | Quit while filled → relaunch opens filled (not boxed short width) | ⬜ |

---

## Summary

After macOS 27, AppKit `zoom` with Forja’s hidden titlebar + `fullSizeContentView` animates to fill then snaps back. `DesktopWindowGeometry` persisted the snapped frame (`maximized=false`), so every relaunch opened boxed.

**Root fix:** `MainFlutterWindow.zoom` sets `screen.visibleFrame` (toggle restores pre-fill frame) with a **reentrancy gate** so AppKit’s second `zoom` in the same gesture cannot undo the fill (that caused the fill→flash→boxed regression). Async re-assert if Tahoe reverts once. Boot clears aspect/max caps. Geometry schema v3 drops corrupt prefs and opens at work-area size (no small→fill flash). Tall-narrow snap frames are not persisted.

## Related

- `apps/forja/macos/Runner/MainFlutterWindow.swift`
- `apps/forja/lib/shell/desktop/desktop_window_geometry.dart`
- `apps/forja/lib/app/bootstrap.dart`
- [196](196-[fixed]-desktop-window-size-resets-after-player.md)
