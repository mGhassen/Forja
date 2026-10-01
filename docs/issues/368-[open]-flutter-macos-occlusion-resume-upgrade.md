# 368 — Upgrade Flutter for macOS occlusion resume (engine #188772)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Flutter SDK pin · macOS desktop  
**Reported:** 2026-09-24

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I368-T01 | Confirm stable/beta Flutter includes `handleWillBecomeActive` fix from [#188772](https://github.com/flutter/flutter/pull/188772) | ⬜ |
| 2 | I368-T02 | Bump CI + local Flutter past the fix; verify Cmd-Tab without AppDelegate lifecycle nudge | ⬜ |
| 3 | I368-T03 | Remove [367](367-[workaround]-macos-cmd-tab-frame-freeze.md) AppDelegate `flutter/lifecycle` nudge + related comments | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I368-A01 | After upgrade, Cmd-Tab freeze gone with AppDelegate nudge deleted | ⬜ |
| 2 | I368-A02 | CI `FLUTTER_CHANNEL` / pinned version documents the minimum that includes the fix | ⬜ |

---

## Summary

Root for the macOS Cmd-Tab frozen-frame bug. Today we ship Flutter **3.44.6** (engine still re-sends `hidden` on becomeActive). Master already resumes from `NSWindow.isVisible`. Workaround lives in [367](367-[workaround]-macos-cmd-tab-frame-freeze.md) until this upgrade lands.

**Related:** [367](367-[workaround]-macos-cmd-tab-frame-freeze.md) · [flutter#155977](https://github.com/flutter/flutter/issues/155977)
