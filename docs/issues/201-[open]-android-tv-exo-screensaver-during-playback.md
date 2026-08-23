# 201 — Android TV Exo screensaver during playback

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** player · Android TV · ExoPlayer · IPTV

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I201-T01 | Native Exo host: `FLAG_KEEP_SCREEN_ON` while `playWhenReady` and not idle/ended | ✅ |
| 2 | I201-T02 | IPTV Exo: re-`WakelockPlus.enable()` on `playing=true` (MediaKit Video parity) | ✅ |
| 3 | I201-T03 | VOD Exo screen: same wakelock re-hold on `playing=true` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I201-A01 | Physical ATV IPTV Exo: watch ≥15 min with no remote input — no screensaver / Ambient | ⬜ |
| 2 | I201-A02 | Physical ATV IPTV MediaKit: still no screensaver (no regression) | ⬜ |

---

## Summary

IPTV Exo on Android TV: after a period with no remote input the TV enters screensaver / Ambient Mode. MediaKit on the same channel stays awake.

**Cause:** ATV Ambient is suppressed by window `FLAG_KEEP_SCREEN_ON` during user-initiated playback. MediaKit’s `Video` widget re-acquires `wakelock_plus` on every `playing=true`. Exo only called `WakelockPlus.enable()` once in `initState`; PlatformView `PlayerView.keepScreenOn` does not reliably keep the Activity flag. Engine switch MediaKit→Exo can also clear the flag via MediaKit’s wakelock refcount `disable()`.

**Fix:** Exo native host sets/clears `FLAG_KEEP_SCREEN_ON` from `playWhenReady` + playback state; Dart re-enables wakelock on Exo `playing=true` (IPTV + VOD).
