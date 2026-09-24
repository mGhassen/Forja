# 367 — macOS Cmd-Tab freezes UI / video (Flutter lifecycle stuck hidden)

**Status:** workaround  
**Priority:** P0  
**Severity:** Critical  
**Area:** `macos/Runner/AppDelegate.swift` · `app/bootstrap.dart`  
**Reported:** 2026-09-24  
**Workaround:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** workaround · **0 / 2** acceptance (manual) |
| **Root** | Open — [368](368-[open]-flutter-macos-occlusion-resume-upgrade.md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I367-T01 | On `applicationDidBecomeActive`, if any window is visible, send `AppLifecycleState.resumed` on `flutter/lifecycle` | ✅ |
| 2 | I367-T02 | Keep `FlutterViewController` from shell channel setup so the nudge can reach the engine | ✅ |
| 3 | I367-T03 | Dart: `scheduleForcedFrame` on macOS window focus (belt for texture paint) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I367-A01 | macOS: Cmd-Tab away and back — Home / posters keep animating; no frozen last frame | ⬜ |
| 2 | I367-A02 | macOS: playing video, Cmd-Tab away and back — picture resumes (not last-frame freeze) | ⬜ |

---

## Summary

After [364](fixed/364-[fixed]-desktop-focus-sync-storm.md) removed the focus sync storm, Cmd-Tab still left the **image / UI frozen**. Local Flutter **3.44.6** still has the buggy `handleWillBecomeActive` that re-sends `hidden` when macOS never delivers a visible occlusion update ([flutter#155977](https://github.com/flutter/flutter/issues/155977)). Framework then gates frames — last painted frame sticks.

**Symptom fix / workaround:** AppKit `didBecomeActive` nudges `resumed` when a window is visible (same rule as upstream [#188772](https://github.com/flutter/flutter/pull/188772)). Dart also forces one frame on window focus.

**Root fix:** Upgrade Flutter once #188772 is on the channel we ship — [368](368-[open]-flutter-macos-occlusion-resume-upgrade.md). Then remove the AppDelegate nudge.

**Related:** [364](fixed/364-[fixed]-desktop-focus-sync-storm.md) · [flutter#155977](https://github.com/flutter/flutter/issues/155977)
