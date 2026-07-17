# 078 — Switches not in design system

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** design system, Settings, player chrome

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I78-T01 | Add `ForjaSwitch` + `forjaSwitchThemeData` in `shared/design/` | ✅ |
| 2 | I78-T02 | Wire `AppTheme.switchTheme` to shared tokens | ✅ |
| 3 | I78-T03 | Migrate settings / player / audiobook raw `Switch` call sites to `ForjaSwitch` | ✅ |
| 4 | I78-T04 | Drop ad-hoc Nuvio `SwitchListTile` thumb override (inherits theme) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I78-A01 | Playback Play sources toggles use `ForjaSwitch` (same tokens as theme) | ✅ |
| 2 | I78-A02 | Navigation visibility, Episodes Auto next, subtitle Bold, audiobook autoplay use `ForjaSwitch` | ✅ |
| 3 | I78-A03 | No raw `Switch(` outside `forja_switch.dart` in app lib | ✅ |

---

## Summary

Switch styling lived only inside `SettingsToggleRow`. Other screens used Material `Switch` / `SwitchListTile` with one-off colors, so redesigns did not propagate.

**Root fix:** canonical `ForjaSwitch` + theme `switchTheme` in the design system; call sites use the shared widget (or inherit theme for list tiles).
