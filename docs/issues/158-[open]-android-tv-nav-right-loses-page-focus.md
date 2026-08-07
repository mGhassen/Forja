# 158 — Android TV: nav RIGHT loses last page focus

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell nav · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I158-T01 | Nav rail RIGHT uses `handleNavKey` → `_navRestoreTabId` (details/search overlay memory) | ✅ |
| 2 | I158-T02 | Snapshot tab memory before restore; sync `requestFocus` (no empty unfocus → Play autofocus race) | ✅ |
| 3 | I158-T03 | Coordinator tests: overlay details restore + mid-restore memory pollution | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I158-A01 | Android TV details: focus episode → ← nav → → returns to that episode (not Play) | ⬜ |
| 2 | I158-A02 | Android TV Home/Anime/catalog: focus a mid-row card → ← nav → → returns to that card | ⬜ |

---

## Summary

From any page, D-pad **←** to the shell nav then **→** should restore the last focused control. Instead focus jumped to the page default (usually hero **Play**).

**Root cause:**

1. Rail **→** called `restoreTabFocusAfterNav(currentNavTabId)` and skipped `_navRestoreTabId`, so overlay details/search memory under `media-details` / `search` was ignored.
2. Restore unfocused the rail first; Flutter autofocused **Play**, which overwrote tab memory via `notifyFocused` before the post-frame restore ran.

**Symptom fix = root fix** in `shell_nav_rail.dart` + `shell_tv_coordinator.dart`.
