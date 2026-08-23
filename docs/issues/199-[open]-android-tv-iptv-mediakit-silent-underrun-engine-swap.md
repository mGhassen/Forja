# 199 — Android TV IPTV MediaKit: silent underrun + Reload auto-swaps engine

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV live player (Android TV, MediaKit) · `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart`  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 4** acceptance |
| **Current slice** | Code landed — ATV MediaKit live smoke outstanding |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I199-T01 | Live MediaKit: `cache-pause=yes` + `cache-pause-initial=yes` (continuity proxy absorbs CDN closes — revisit [I148-T20](148-[open]-iptv-live-edge-snap-reconnect-loop.md)) so underrun pauses and refills instead of freezing silently | ✅ |
| 2 | I199-T02 | Live never auto-swaps MediaKit↔Exo on unrecognized-format / hard-open errors (Reload / empty reopen) — Player menu only; guard call sites + `_autoSwapEngineForFormatError` | ✅ |
| 3 | I199-T03 | Feed / proxy ticks must not fake playhead or hide **Buffering…** when demuxer cache is empty (`_videoAdvancing`, `_playheadRecentlyMoved`, `_noteFeedProgress`, `_streamWorking`) | ✅ |
| 4 | I199-T04 | Watchdog: MediaKit live underrun while still “playing” shows Buffering and soft-reopens; self-pause hold no longer treats feed-only as healthy | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I199-A01 | Android TV MediaKit live: when cache runs dry, **Buffering…** appears and playback resumes after refill (or soft reconnect) — no silent frozen frame | ⬜ |
| 2 | I199-A02 | Android TV MediaKit live: **Reload** stays on MediaKit — does not flip to ExoPlayer unless the user picks Exo in **Player** | ⬜ |
| 3 | I199-A03 | Healthy live channel still plays without reconnect thrash from proxy keepalives (no false “dead” every few seconds) | ⬜ |
| 4 | I199-A04 | IPTV Movies/Series (VOD) format hard-open can still one-shot swap engines | ⬜ |

---

## Summary

**Symptom:** On Android TV IPTV with MediaKit, a live channel could stall with empty cache and **no Buffering banner**. **Reload** sometimes restarted on **ExoPlayer** without the user changing the engine.

**Root cause:**

1. Live MediaKit used `cache-pause=no` ([I148-T20](148-[open]-iptv-live-edge-snap-reconnect-loop.md)) so underrun kept “playing” on a frozen frame instead of pausing to refill.
2. Continuity-proxy / demuxer feed ticks marked the stream “alive”, so the Buffering chrome gate and Stable recovery treated a frozen picture as healthy.
3. MediaKit “failed to recognize file format” after Reload / empty reopen auto-swapped to Exo on **live** (no live/VOD gate).

**Fix:** Pause-to-refill on live again (proxy still absorbs CDN closes), never auto-swap engines on live, and stop counting empty-cache feed ticks as playhead / healthy.

**Related:** [issue 148](148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [issue 128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) (Reload ANR watch)
