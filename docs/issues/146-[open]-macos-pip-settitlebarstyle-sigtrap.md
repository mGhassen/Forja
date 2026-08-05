# 146 — Desktop PiP: window_manager setTitleBarStyle SIGTRAP

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/services/pip_service.dart` · `window_manager` (macOS/Windows)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I146-T01 | After native `DesktopPipChannel` borderless chrome, stop calling `windowManager.setTitleBarStyle` / `setAsFrameless` (enter + leave) | ✅ |
| 2 | I146-T02 | Notify PiP listeners / treat `isDesktopActive` before window resize so full IPTV/VOD chrome never lays out in the ~360px frame | ✅ |
| 3 | I146-T03 | Stub IPTV catalog shell while desktop PiP active; top-bar tools `Flexible`+scroll so underlay cannot overflow at PiP width | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I146-A01 | macOS: IPTV or VOD playing → Space switch auto-PiP → restore — no SIGTRAP, no RenderFlex overflow cascade, no process death | ⬜ |

---

## Summary

Crash report (1.3.114, macOS 26.5): `EXC_BREAKPOINT` / Swift runtime failure on main thread:

`WindowManager.setTitleBarStyle` (`WindowManager.swift:396`) ← `WindowManagerPlugin.handle`.

**Symptom:** App dies when entering (or restoring from) desktop picture-in-picture — often right after Space switch auto-PiP while media_kit/mpv is playing. Process role Background; mpv threads alive.

**Root:** `DesktopPipChannel.applyPipChrome` sets `styleMask = [.borderless, …]` (no traffic lights). `PipService` then called `window_manager.setTitleBarStyle`, which does:

```swift
(mainWindow.standardWindowButton(.closeButton)?.superview)!.superview!
```

`closeButton` is nil on a borderless window → force unwrap → SIGTRAP. Dart `try/catch` does not catch native traps. Distinct from [145](145-[open]-macos-live-embed-webkit-fullscreen-crash.md) (WK fullscreen).

**Fix (shipped in code):** Rely on native PiP chrome for hide/restore title bar. Never call `setTitleBarStyle` / `setAsFrameless` on the enter/leave path after native chrome is applied. Fire `desktopPipChanges(true)` and treat `isDesktopActive` (enter-pending) before `setSize`, so IPTV/VOD full chrome is swapped for `DesktopPipOverlay` before the window shrinks. While desktop PiP is active, stub the underlay IPTV catalog shell (black box) and make catalog top-bar tools `Flexible`+horizontal scroll so a ~214px slot cannot RenderFlex-overflow.
