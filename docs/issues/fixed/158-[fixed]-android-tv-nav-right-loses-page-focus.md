# 158 — Android TV: nav RIGHT loses last page focus

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · shell nav · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I158-T01 | Nav rail RIGHT uses `handleNavKey` → `_navRestoreTabId` (details/search overlay memory) | ✅ |
| 2 | I158-T02 | Snapshot tab memory before restore; sync `requestFocus` (no empty unfocus → Play autofocus race) | ✅ |
| 3 | I158-T03 | Coordinator tests: overlay details restore + mid-restore memory pollution | ✅ |
| 4 | I158-T04 | Flush FocusManager on restore; never `_restoreDefault` (hero + scroll-to-top) while row/grid memory exists — ATV home ← nav → flash | ✅ |
| 5 | I158-T05 | Freeze page focus on ← to nav (`_captureFocusBeforeNav`); details episode survives Play pollution before → | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I158-A01 | Android TV details: focus episode → ← nav → → returns to that episode (not Play) | ✅ |
| 2 | I158-A02 | Android TV Home/Anime/catalog: focus a mid-row card → ← nav → → returns to that card | ✅ |

---

## Summary

From any page, D-pad **←** to the shell nav then **→** should restore the last focused control. Instead focus jumped to the page default (usually hero **Play**).

**Root cause:**

1. Rail **→** called `restoreTabFocusAfterNav(currentNavTabId)` and skipped `_navRestoreTabId`, so overlay details/search memory under `media-details` / `search` was ignored.
2. Restore unfocused the rail first; Flutter autofocused **Play**, which overwrote tab memory via `notifyFocused` before the post-frame restore ran.
3. **Regression (I158-T04):** `FocusNode.requestFocus` only *marks* the next focus (applied in a microtask). Sync restore marked the catalog card, then `_pageHasFocus()` still saw the nav and fell through to `_restoreDefault` → marked **hero Play** + `revealHero` scroll-to-top; a post-frame pass then reclaimed the card. Viewport fought itself; D-pad after felt lost.
4. **Details (I158-T05):** Leaving an episode for the rail let details **Play** steal focus for a frame and overwrite `media-details` memory before RIGHT — restore then preferred Play. Freeze memory in `focusActiveNavTab` / Back-to-nav before the transfer.

**Symptom fix = root fix** in `shell_nav_rail.dart` + `shell_tv_coordinator.dart`.
