# 521 — Mobile bottom nav chrome diverged from rail

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Android phone · shell nav · chrome  
**Reported:** 2026-10-29 (manual on phone emulator)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Phone bottom tab bar used a selected pill + Material ink wash and white/white54 icons — not the desktop/TV rail language (destination accent, underline, hover scale/color). Placement on the bottom was fine; the item paint was wrong.

## Root cause

`ShellBottomNav` / `_BottomNavItem` was a separate paint path from `_NavRailDestination` (`shell_nav_rail.dart`). RFC-025 only flattened the bar (no blur); it never shared rail chrome. Mobile `ShellInputPolicy.scaleOnHover` is also off, so even a shared helper would need the bar to track hover itself.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I521-T01 | Port rail accent / underline / hover-scale / no-ink language onto `_BottomNavItem` + More sheet rows | ✅ |
| 2 | I521-T02 | Widget tests: selected accent+underline, hover accent, More selected color | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I521-A01 | `flutter test test/shell_mobile_chrome_test.dart` green | ✅ |
| 2 | I521-A02 | Manual: phone emulator bottom bar selected + hover matches rail accents | ⬜ |

## Links

- RFC-025 flat cinematic shell (R25-A13 flattened bottom nav only)
- RFC-028 adaptive shell profiles (mobile bottom nav placement)
