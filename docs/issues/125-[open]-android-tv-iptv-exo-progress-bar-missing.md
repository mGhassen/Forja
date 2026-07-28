# 125 — Android TV IPTV Exo progress bar missing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · ExoPlayer  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I125-T01 | Exo progress: apply duration even when position is still 0; setState when duration first arrives | ✅ |
| 2 | I125-T02 | Exo native: emit `contentDuration` / timeline window when `Player.duration` is unset | ✅ |
| 3 | I125-T03 | IPTV chrome: always show progress row — VOD scrubber, live EPG (or live-edge) track + logo + time | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I125-A01 | Android TV IPTV live (Exo): controls show logo + green progress track (EPG fill when guide exists) | ⬜ |
| 2 | I125-A02 | Android TV IPTV movie/series (Exo): scrubber appears once duration is known (including at 0:00) | ⬜ |

---

## Summary

On **Android TV** with **ExoPlayer**, IPTV chrome often had **no progress bar**: live hid the row entirely (`_isVod` false when duration is 0), and VOD could stay without a scrubber when Exo reported duration while position was still `0` (duration update was gated on position change).

**Fix:** always show the progress row; live uses EPG progress (or a full live-edge track); Exo duration plumbing fixed so VOD mounts the scrubber as soon as duration is known.

**Related:** [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) · [122](122-[open]-android-tv-iptv-player-lost-dpad.md) · [iptv-xtream](../features/live/iptv-xtream.md)
