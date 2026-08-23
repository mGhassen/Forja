# 197 — Android TV trailer quality switch does nothing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · YouTube quality  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |
| **Current slice** | Code fix landed — device smoke remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-T01 | `resetPlayerForOpen` before trailer reopen (quality / trailer swap) so ATV MediaCodec drops the prior demuxer | ✅ |
| 2 | I197-T02 | `waitForPlayerStreamOpen` before seek on reopen | ✅ |
| 3 | I197-T03 | ATV quality switch: `forceAudioAdd` (do not skip audio-add on stale tracks) | ✅ |
| 4 | I197-T04 | Strip googlevideo self-Referer in `resolvePlaybackHttpHeaders` (mpv 403 on quality reopen) | ✅ |
| 5 | I197-T05 | Trailer reopen: poll ready without `waitForPlayerStreamOpen` error settle (stop() abort poisoned quality switch) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-A01 | Android TV: open a trailer → Quality → pick another height — picture resolution changes (not stuck on first stream) | ⬜ |
| 2 | I197-A02 | Android TV: after quality switch, audio still present and position roughly resumes | ⬜ |

---

## Summary

Trailer **Quality** on Android TV updated the checkmark but playback stayed on the first googlevideo URL (or went silent). Logs showed `HTTP error 403 Forbidden` on quality reopen.

**Root cause (stacked):**
1. **403:** `resolvePlaybackHttpHeaders` derived googlevideo self-Referer → CDN reject on reopen.
2. **False open fail:** after `resetPlayerForOpen`/`stop()`, mpv abort noise (`HTTP error` / `Failed to open`) made `waitForPlayerStreamOpen` settle false immediately — adaptive quality never stuck; recovery reopened muxed **360p**.
3. **Stale audio tracks** on ATV MediaCodec without forced `audio-add`.

**Fix:** strip googlevideo Referer/Origin; trailer reopen polls `isMediaOpenReady` without fatal error settle; quality switch always `forceAudioAdd`; failed switch recovers prior stream.

## Related

- [RFC-055](../rfc/055-[open]-native-youtube-trailer-player.md)
- [154](154-[open]-android-tv-trailer-player-dpad.md) — ATV trailer D-pad
- [Media details](../features/movies-tv/media-details.md)
