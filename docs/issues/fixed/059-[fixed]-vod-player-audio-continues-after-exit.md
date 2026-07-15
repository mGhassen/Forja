# 059 — Movie/TV player audio continues after exit

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/player` media_kit desktop/mobile · ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0/1** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I59-T01 | Desktop `_exitPlayer`: mute + `stop()` before `Navigator.pop` | ✅ |
| 2 | I59-T02 | Mobile `_exitPlayer` + PopScope: mute + `stop()` before orientation/pop | ✅ |
| 3 | I59-T03 | Desktop/mobile `dispose`: stop-then-dispose (IPTV pattern), not dispose-only | ✅ |
| 4 | I59-T04 | ExoPlayer `_exit` + dispose: `stop()` before/with teardown | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I59-A01 | App: play a movie/TV stream, hear audio, Back/Escape — audio stops immediately (desktop + mobile; Exo if used) | ⬜ |

---

## Summary

Exiting the VOD player left mpv/Exo audio playing after the route closed. Back only cancelled work and popped; widget `dispose` fire-and-forgot `player.dispose()` (desktop even swallowed errors) without an explicit `stop()` first.

### Root cause

- Desktop/mobile `_exitPlayer` never called `player.stop()` before pop.
- `dispose` relied on media_kit’s internal stop inside `dispose()`, which waits on init gates and was not awaited — UI gone while audio could continue.
- IPTV already used `await stop()` then `await dispose()`; VOD did not.

### Fix (shipped)

- `_stopPlaybackForExit()` — mute + stop before pop (desktop + mobile).
- `_teardownMediaKitPlayer()` — stop then dispose on widget dispose (same as IPTV).
- Exo: `ExoPlayerBridge.stop` on exit and before dispose.

Live Matches WebView leftover audio is a separate bug ([058](058-[fixed]-live-embed-audio-continues-after-exit.md)).

### Verify

1. Open a movie or TV episode until audio plays
2. Back / Escape out of the player
3. Audio must stop immediately on the details/home screen

## Related

- [058](058-[fixed]-live-embed-audio-continues-after-exit.md) — Live Matches WebView (same user symptom, different engine)
- [Player](../../features/playback/player.md)
