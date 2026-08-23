# 197 — Android TV trailer quality switch does nothing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · YouTube quality  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |
| **Current slice** | Code fix landed — device smoke remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-T01 | `resetPlayerForOpen` before trailer reopen (quality / trailer swap) so ATV MediaCodec drops the prior demuxer | ✅ |
| 2 | I197-T02 | `waitForPlayerStreamOpen` before seek on reopen | ✅ |
| 3 | I197-T03 | ATV quality switch: `forceAudioAdd` (do not skip audio-add on stale tracks) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-A01 | Android TV: open a trailer → Quality → pick another height — picture resolution changes (not stuck on first stream) | ⬜ |
| 2 | I197-A02 | Android TV: after quality switch, audio still present and position roughly resumes | ⬜ |

---

## Summary

Trailer **Quality** on Android TV updated the checkmark but playback stayed on the first googlevideo URL (or went silent).

**Root cause:** `_switchQuality` called `openPlayerStream` on the live MediaKit player without `stop()`. On ATV `mediacodec_embed`, that often keeps the old demuxer. Separately, `_waitForSelectableAudio` could see leftover audio tracks and skip `audio-add`, so adaptive qualities opened video-only.

**Fix:** same hot-swap ladder as the main player — `resetPlayerForOpen` → open → `waitForPlayerStreamOpen` → seek; on ATV quality switch always `audio-add` (`forceAudioAdd`).

## Related

- [RFC-055](../rfc/055-[open]-native-youtube-trailer-player.md)
- [154](154-[open]-android-tv-trailer-player-dpad.md) — ATV trailer D-pad
- [Media details](../features/movies-tv/media-details.md)
