# 384 — Desktop clicks wait before they act

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Shell tabs · nav · buttons · catalog cards  
**Reported:** 2026-09-25

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I384-T01 | Hidden shell tabs stay offstage — do not lay them out on every shell rebuild | ✅ |
| 2 | I384-T02 | Mouse primary click runs the action on pointer down (nav without a long-press, buttons, switches, focusable taps) | ✅ |
| 3 | I384-T03 | Cloud soft-pull on tab select runs after the tab paints | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I384-A01 | Desktop: click nav, a poster, and a Settings control — the action starts on press, not after a hitch | ⬜ |

---

## Summary

Every desktop click felt dead for a short moment. Two things stacked:

1. Kept-alive hubs were `Visibility(maintainSize: true)`, so a shell rebuild laid out every mounted tab before the click’s own work ran.
2. Taps used `GestureDetector.onTap`, which loses the arena to a competing long-press or double-tap and only wins on pointer up (up to the 100ms press timeout, 300ms if a double-tap recognizer is in the tree).

Mouse clicks now call the action on pointer down. Surfaces that need a parent long-press or double-tap (poster Open with, channel EPG, season/episode watched) stay on pointer up so those gestures still win. Cloud soft-pull on a tab change waits until the next frame.

**Root fix:** yes for the layout and the mouse-down path. Acceptance still needs a click on the running app.
