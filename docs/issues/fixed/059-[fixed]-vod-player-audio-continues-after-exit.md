# 059 — Movie/TV player audio continues after exit

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/player` media_kit desktop/mobile · ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 7/7** fix · **0/1** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I59-T01 | Desktop `_exitPlayer`: mute + `stop()` before `Navigator.pop` | ✅ |
| 2 | I59-T02 | Mobile `_exitPlayer` + PopScope: mute + `stop()` before orientation/pop | ✅ |
| 3 | I59-T03 | Desktop/mobile `dispose`: stop-then-dispose (IPTV pattern), not dispose-only | ✅ |
| 4 | I59-T04 | ExoPlayer `_exit` + dispose: `stop()` before/with teardown | ✅ |
| 5 | I59-T05 | Desktop top-bar Back wired to `_exitPlayer` (was a direct pop that skipped stop) | ✅ |
| 6 | I59-T06 | `silenceMediaKitPlayer`: native mute/pause/`ao=null` with `waitForInitialization: false` | ✅ |
| 7 | I59-T07 | `teardownMediaKitPlayer`: stop+dispose with timeouts so hung locks cannot leave audio | ✅ |

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
- Desktop top-bar Back had a **separate** handler that popped without calling `_exitPlayer` at all — so the first stop-before-pop fix never ran on the UI back button.
- `player.stop()` / `dispose()` await media_kit video-controller init; if that hangs, exit never completes and audio never dies.
- media_kit delays `mpv_terminate_destroy` by 5s after dispose — silence must happen via mpv properties before that.

### Fix (shipped)

- Top-bar Back → `_exitPlayer` (desktop).
- `silenceMediaKitPlayer` — `mute`/`pause`/`volume=0`/`ao=null` with `waitForInitialization: false`.
- `teardownMediaKitPlayer` — silence + timed `stop` + timed `dispose`.
- Exo: `ExoPlayerBridge.stop` on exit and before dispose.

Live Matches WebView leftover audio is a separate bug ([058](058-[fixed]-live-embed-audio-continues-after-exit.md)).

### Verify

1. Open a movie or TV episode until audio plays
2. Tap the player **Back** button (not only Escape)
3. Player must close and audio must stop immediately

## Related

- [058](058-[fixed]-live-embed-audio-continues-after-exit.md) — Live Matches WebView (same user symptom, different engine)
- [Player](../../features/playback/player.md)
