# 125 — Android TV IPTV Exo progress bar missing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · IPTV player · ExoPlayer  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 4** acceptance |
| **Current slice** | T05: ATV Exo VOD scrubber shown again (like MediaKit); live Exo track still hidden |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I125-T01 | Exo progress: apply duration even when position is still 0; setState when duration first arrives | ✅ |
| 2 | I125-T02 | Exo native: emit `contentDuration` / timeline window when `Player.duration` is unset | ✅ |
| 3 | I125-T03 | IPTV chrome: always show progress row — VOD scrubber, live EPG (or live-edge) track + logo + time | ✅ |
| 4 | I125-T04 | Android TV Exo: hide bottom progress row (live track and VOD scrubber); keep transport + ←/→ VOD seek | ✅ |
| 5 | I125-T05 | Android TV Exo **VOD**: show progress scrubber again (parity with MediaKit chrome); live Exo track stays hidden | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I125-A01 | Android TV IPTV live (Exo): controls show logo + green progress track (EPG fill when guide exists) | ⬜ |
| 2 | I125-A02 | Android TV IPTV movie/series (Exo): scrubber appears once duration is known (including at 0:00) | ⬜ |
| 3 | I125-A03 | Android TV IPTV **live** (Exo): bottom progress row is absent; transport controls remain | ⬜ |
| 4 | I125-A04 | Android TV IPTV **movie/series** (Exo): scrubber visible like MediaKit once duration is known; ←/→ seek still works | ⬜ |

---

## Summary

On **Android TV** with **ExoPlayer**, IPTV chrome often had **no progress bar**: live hid the row entirely (`_isVod` false when duration is 0), and VOD could stay without a scrubber when Exo reported duration while position was still `0` (duration update was gated on position change).

**Fix (duration plumbing):** Exo duration updates apply even at position 0 so VOD can mount a scrubber when duration is known (`I125-T01`–`T02`).

**Product (ATV Exo chrome):** `I125-T04` hid the entire ATV Exo progress row. **`I125-T05`:** VOD scrubber is shown again on ATV Exo (MediaKit parity). Live Exo still hides the EPG/live-edge track (`I125-A03`). Phone/desktop unchanged.

**Related:** [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) · [122](122-[open]-android-tv-iptv-player-lost-dpad.md) · [iptv-xtream](../features/live/iptv-xtream.md)
