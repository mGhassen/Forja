# 484 — Android TV details: no way to mark episode watched

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · media details · episode picker  
**Reported:** 2026-10-24 (remote: press episode to check seen — dead on leanback)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV details, short OK selects / second OK plays an episode. There is no remote gesture to toggle the watched check. Double-tap / right-click only work with a pointer.

## Root cause (verified in code)

`TvSeasonEpisodePicker` wired `onToggleWatched` only to `GestureDetector.onDoubleTap` / `onSecondaryTap` on chips and cards (and seasons). No OK-hold / MENU path. Catalog posters already use hold-OK + MENU via `InteractivePosterCard`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I484-T01 | Shared `TvOkHold` (OK-up short / hold / MENU) at catalog hold delay | ✅ |
| 2 | I484-T02 | Episode chips + cards: hold OK / MENU / pointer long-press toggles watched; short OK select/play unchanged | ✅ |
| 3 | I484-T03 | Season cards: same hold toggles season watched when host provides it | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I484-A01 | Unit: `tv_ok_hold_test` short / hold / MENU / wrapTap | ✅ |
| 2 | I484-A02 | Physical / emulator TV: hold OK on episode toggles check; second short OK still plays | ⬜ |

## Links

- [RFC-122](../rfc/122-[draft]-android-tv-remote-ux.md) — catalog OK-hold / MENU quick menu
- [459](459-[open]-android-tv-series-journey-search-space-episode-ok-next-season.md) — episode short OK select / play
