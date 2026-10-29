# 518 — Android TV: remote power kills process (Xiaomi standby bounce)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · `MainActivity` power / `SCREEN_OFF`  
**Reported:** 2026-10-29

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **1 / 1** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I518-T01 | Remove TV power-key consume + `SCREEN_OFF`/`SHUTDOWN` → `exitCompletely` from `MainActivity` (keep double-Back / Exit kill only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I518-A01 | Xiaomi Box S (or similar): power while Forja open → box stays in standby; wake does not bounce back into Forja mid-sleep | ⬜ |

---

## Summary

Released Android TV on **Xiaomi Box S**: pressing power briefly shut the box down then returned into Forja.

**Root cause:** [issue 119](../119-[open]-android-tv-double-back-exit.md) `I119-T05` / RFC-028 `R28-A31` made TV intercept `KEYCODE_POWER` (and siblings), return `true` (consume), and call `finishAndRemoveTask` + `killProcess`. The same kill ran on `ACTION_SCREEN_OFF` / `ACTION_SHUTDOWN`. On Xiaomi that races standby and aborts sleep → UI comes back.

**Root fix:** Power and screen-off no longer quit Forja. Only double-Back / remote Exit still call `exitAppCompletely`. System owns standby.

## Related

- [119](../119-[open]-android-tv-double-back-exit.md) — double Back / Exit (T05 power quit reversed by this issue)
- [RFC-028](../../rfc/028-[draft]-adaptive-shell-profiles.md) — `R28-A32` supersedes power-quit `R28-A31`
