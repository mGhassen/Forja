# 124 — Android TV IPTV reconnect banner stays after stream recovers

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · IPTV player · ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I124-T01 | Exo: map buffering from `STATE_BUFFERING` / ready — not `isLoading` (live prefetch stuck reconnect UI) | ✅ |
| 2 | I124-T02 | IPTV watchdog / Exo+MediaKit ready-playing: clear `Reconnecting…` when frames move again (do not gate on `!buffering`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I124-A01 | Android TV IPTV live: after Reconnecting 1/8 and video resumes, banner dismisses within a few seconds (no stuck overlay) | ⬜ |

---

## Summary

On **Android TV** (Exo default), a brief IPTV stall shows **Reconnecting… (attempt 1/8)**. When the feed comes back, video/audio play again but the banner can stay forever.

**Root cause:** `ForjaExoPlayerPlugin` mapped Exo `isLoading` → Flutter `buffering`. Live streams stay `isLoading` while playing (prefetch). The IPTV watchdog only cleared the reconnect banner on a healthy streak that required `!_buffering`, so the UI never dismissed. Soft recovery also skipped `_openCurrent`’s delayed banner clear.

**Root fix:** emit buffering from `STATE_BUFFERING` / `STATE_READY`; clear reconnect banner when playback resumes (ready/playing + position moving), independent of the `isLoading` flicker.

## Related

- [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) — Windows freeze / reconnect banner
- [108](108-[open]-android-tv-iptv-exo-choppy-fps.md) — ATV Exo live path
- [IPTV Xtream](../features/live/iptv-xtream.md) · [Player](../playback/player.md)
