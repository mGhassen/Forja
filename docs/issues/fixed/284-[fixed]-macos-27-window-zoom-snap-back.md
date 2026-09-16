# 284 — macOS 27: window-bar zoom fills then snaps back

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop / macOS / window chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I284-T01 | Override `NSWindow.zoom` to fill/restore `visibleFrame` (hidden titlebar) | ✅ |
| 2 | I284-T02 | Clear aspect/max on boot; schema-bump drop corrupt geometry prefs; settle save | ✅ |
| 3 | I284-T03 | Changelog + platforms note | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I284-A01 | macOS 27: double-click title bar / green zoom fills work area and stays | ⬜ |
| 2 | I284-A02 | Quit while filled → relaunch opens filled (not boxed short width) | ⬜ |

---

## Summary

After macOS 27, AppKit `zoom` with Forja’s hidden titlebar + `fullSizeContentView` animates to fill then snaps back. `DesktopWindowGeometry` persisted the snapped frame (`maximized=false`), so every relaunch opened boxed.

**Root fix:** `MainFlutterWindow.zoom` sets `screen.visibleFrame` (toggle restores pre-fill frame). Boot clears aspect/max caps. Geometry schema v2 drops corrupt prefs once and opens maximized on macOS. Maximize/unmaximize suppress mid-settle saves.

## Related

- `apps/forja/macos/Runner/MainFlutterWindow.swift`
- `apps/forja/lib/shell/desktop/desktop_window_geometry.dart`
- `apps/forja/lib/app/bootstrap.dart`
- [196](196-[fixed]-desktop-window-size-resets-after-player.md)
