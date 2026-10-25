# 483 — Android TV Settings ←/Back skips category menu → profile nav

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings hub · D-pad / Back  
**Reported:** 2026-10-25 (device)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV Settings (split hub):

1. Focus on a **settings page** (right pane) → **←** does nothing (trapped).
2. **Back** jumps to the shell Settings rail (**profile avatar**), skipping the left **settings menu** (category list).
3. Expected ladder: settings detail → settings page → settings menu → shell nav. Each Back / ← toward the menu moves **one** level.

## Root cause

`SettingsHubScaffold._handlePageBack` only moved focus to the category rail when `_detailScope.hasFocus` was true. Some page controls sit outside that `FocusScope` in the focus tree, so pageBack returned **false**. ContainDpad then swallowed **←**, and shell Back called `_focusActiveNavFromPage()` → profile / Settings nav icon.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I483-T01 | pageBack: detect category rail via `rowHasFocus` / pinned tile; otherwise always land selected category (fallback `firstTileFocusNode`) | ✅ |
| 2 | I483-T02 | Widget regression: pageBack page→menu without detail `FocusScope.hasFocus` | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I483-A01 | `dpad_matrix_coverage_test` I483 case passes | ✅ |
| 2 | I483-A02 | Android TV: page ←/Back → selected category; next Back → nav; drill Back → page first | ⬜ |

## Links

- [127](127-[fixed]-android-tv-settings-detail-dpad.md) — original detail ←/Back ladder
- [257](../257-[open]-android-tv-guest-settings-only-dpad.md) — Settings-only rail / pageBack bind
