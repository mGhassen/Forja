# 197 — Android TV trailer quality switch does nothing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · YouTube quality  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |
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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-A01 | Android TV: open a trailer → Quality → pick another height — picture resolution changes (not stuck on first stream) | ⬜ |
| 2 | I197-A02 | Android TV: after quality switch, audio still present and position roughly resumes | ⬜ |

---

## Summary

Trailer **Quality** on Android TV updated the checkmark but playback stayed on the first googlevideo URL (or went silent). Logs showed `HTTP error 403 Forbidden` on quality reopen.

**Root cause (two layers):**
1. **403:** `resolvePlaybackHttpHeaders` derived `Referer` / `Origin` from the googlevideo host (`https://*.googlevideo.com/`), which YouTube rejects on videoplayback — especially after `resetPlayerForOpen` reopens a new adaptive URL.
2. **Stale demuxer / audio:** `_switchQuality` reopened without `stop()` on ATV MediaCodec; `_waitForSelectableAudio` could skip `audio-add` on leftover tracks.

**Fix:** strip Referer/Origin for `googlevideo.com` in `resolvePlaybackHttpHeaders`; trailer hot-swap uses `resetPlayerForOpen` → open → `waitForPlayerStreamOpen` → seek, with ATV `forceAudioAdd`; failed switch reopens the prior stream instead of leaving playback dead.

## Related

- [RFC-055](../rfc/055-[open]-native-youtube-trailer-player.md)
- [154](154-[open]-android-tv-trailer-player-dpad.md) — ATV trailer D-pad
- [Media details](../features/movies-tv/media-details.md)
