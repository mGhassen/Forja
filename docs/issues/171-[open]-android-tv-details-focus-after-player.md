# 171 — Android TV details: empty focus after leaving player

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · media details · Anime · Asian Drama · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I171-T01 | `ShellTvFocusCoordinator.claimHeroPlayAfterPlayerExit` — reclaim Play only when page has no usable focus (post-frame retries) | ✅ |
| 2 | I171-T02 | Wire reclaim after player return on movie details, Anime details, Asian Drama details | ✅ |
| 3 | I171-T03 | Always reclaim Play after player exit / loading cancel (do not skip on leftover Cancel/overlay focus) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I171-A01 | Android TV movie/TV details: leave player → D-pad focus on Play/Resume (not empty) | ⬜ |
| 2 | I171-A02 | Android TV Anime details: leave player → D-pad focus on Play/Resume (not empty) | ⬜ |
| 3 | I171-A03 | Android TV Asian Drama details: leave player → D-pad focus on Play/Resume (not empty) | ⬜ |
| 4 | I171-A04 | Android TV: cancel stream loading on details → D-pad focus on Play/Resume | ⬜ |

---

## Summary

On **Android TV**, quitting the VOD player sometimes returned to details with **no focused control** (empty `FocusScope`). D-pad felt dead until another focusable gained focus.

**Root cause:** player pop + `loading_overlay` strip + watch-history rebuild race. Hero Play autofocus is one-shot (`_detailsHeroInitialFocusDone`), so a lost restore was never reclaimed.

**Symptom fix = root fix** in `shell_tv_coordinator.dart` + details play return paths (movies / Anime / Asian Drama). **I171-T03:** leftover Cancel/overlay focus after loading dismiss was treated as “page has focus”, so Play was never reclaimed — now always request Play.
