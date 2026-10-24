# 476 — Android TV: mottled dots on some streams; TV has no working software-decode path

**Status:** draft  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · player · MediaKit / ExoPlayer decode  
**Reported:** 2026-10-24 (physical Xiaomi TV, Android 14 — some streams render with many small dots, mottled / speckled, like a broken encode)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** fix · **0 / 4** acceptance |
| **Current slice** | Triage on device (A01–A02) decides which fix tasks apply |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Symptom

On a physical Xiaomi Android TV (Android 14) some streams play with a dense pattern of small dots over the whole picture. Other streams on the same device are clean. The same titles look clean on desktop.

## What the code does today (verified)

Every leanback player (VOD, IPTV, Live Sports, trailers) creates MediaKit with `vo=mediacodec_embed` + `hwdec=mediacodec`, surface attached before video params (`mobile_player_lifecycle.dart:204-218`, `pt_player_engine.dart:57-64`, `live_sports_player_engine.dart:64-71`, `trailer_player_playback.dart:20-28`). MediaCodec paints straight into the Flutter Surface: no mpv GPU shaders, no dithering, no deband, no tone-map, no deinterlace. Impeller is off for all Android (`AndroidManifest.xml:30-33`); leanback forces SurfaceTexture producers (`ForjaApplication.kt:14-16`, issue 114). The fork's hwdec-codecs list is `h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1` (media_kit fork `android_video_controller/real.dart:194-207`).

Three things cannot be told apart from code and need the device:

1. **Hardware error concealment.** A TS / HLS segment with packet loss decodes with blocky speckle on MediaCodec, while software ffmpeg conceals the damage. This matches "like a stream encoding problem" and "only some streams".
2. **10-bit HEVC / HDR or AV1 film grain through MediaCodec → SurfaceTexture.** Xiaomi (Amlogic / MediaTek) decoders emit P010 / grain-synth frames that the 8-bit external-texture path shows as noise.
3. **Interlaced MPEG-2 / H.264 (IPTV).** No deinterlace on the embed path → combing that reads as dots at TV viewing distance.

## Root cause (the part already provable)

The player's in-player **Video decode** entry (`mobile_player_sources_settings.dart:201-225`) offers HW+ / COPY / SW on Android TV and writes `hwdec=auto-safe|auto-copy|no` live into mpv. The output is pinned to `vo=mediacodec_embed`, which can only present MediaCodec surface frames. COPY and SW therefore stop the picture instead of changing the decoder. `PlaybackRecovery._forceSoftwareDecode` (`playback_recovery.dart:69-78`) and the VOD `onForceSoftwareDecode` hook (`mobile_player_playback.dart:1413-1419`) do the same `hwdec=no` on a decoder error, so the automatic HW→SW fallback from issue 033 is also dead on leanback. The `mediacodec` pin at `mobile_player_playback.dart:1868-1872` runs only at open, so a later chip tap overrides it.

Net effect: a TV user who sees decoder artifacts has no working escape to software decode, and the app silently breaks the picture when they try.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I476-T01 | Player stats panel on TV shows `video-codec`, `video-params/pixelformat`, `hwdec-current`, `video-params/primaries`, interlaced flag — needed to triage A01 | ⬜ |
| 2 | I476-T02 | Leanback MediaKit: Video decode SW / COPY recreates the `VideoController` with `vo=gpu` + the chosen `hwdec` (same pattern as issue 461 T02 on desktop); HW+ keeps `mediacodec_embed` + `mediacodec`. Verify `vo=gpu` paints on Xiaomi now that SurfaceTexture producers are forced (issue 114 T05) | ⬜ |
| 3 | I476-T03 | `PlaybackRecovery` HW→SW fallback on leanback goes through the same controller recreate instead of a bare `hwdec=no` | ⬜ |
| 4 | I476-T04 | If T02 shows `vo=gpu` cannot paint on this chip: Video decode on leanback states that fact in its subtitle and keeps HW+ selected (no hiding — the entry stays) | ⬜ |
| 5 | I476-T05 | If A01 points at 10-bit / HDR: leanback mpv `hwdec-codecs` narrowed to `h264,hevc` and 10-bit HEVC / AV1 routed to `vo=gpu` with `tone-mapping=auto` (desktop already sets this, `desktop_player_playback.dart:1860-1864`) | ⬜ |
| 6 | I476-T06 | If A01 points at damaged TS: leanback IPTV / Live keeps `mediacodec` but enables `vd-lavc-skiploopfilter=none` + mpv `demuxer-lavf-o=fflags=+discardcorrupt` so damaged frames drop instead of painting speckle | ⬜ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I476-A01 | On the Xiaomi: play a dotted stream, open stats; record codec / pixel format / hwdec-current / interlaced. Then Settings → Player → Movies & series engine → ExoPlayer, same stream: dots gone or not | ⬜ |
| 2 | I476-A02 | Same stream on macOS desktop with Video decode HW+ and SW: both clean (rules out the encode itself) | ⬜ |
| 3 | I476-A03 | After T02: Video decode → SW on the Xiaomi keeps the picture (no black / frozen frame) and the dotted stream is clean or at least different | ⬜ |
| 4 | I476-A04 | After T03: a forced decoder error on leanback falls back to software without losing the picture | ⬜ |

## Out of scope

- Exo renderer changes (Media3 1.5.1, extension renderers off): Exo on this device is also hardware MediaCodec, so it is a triage probe, not a fix.
- libmpv Android build flags (`libmpv-android-video-build` v1.1.8 is external).

## Links

- [033](033-[open]-vod-decoder-recovery.md) — HW→SW fallback that this issue shows is inert on leanback
- [114](114-[open]-android-tv-movie-mediakit-audio-only.md) — why leanback uses `mediacodec_embed` + SurfaceTexture producers
- [461](461-[open]-desktop-vod-sw-decode-keeps-hw-texture-pink-green.md) — desktop controller-recreate pattern to reuse for T02
- [215](215-[open]-android-tv-skia-glyph-atlas-glitch.md) — Impeller / Skia state on leanback (docs vs manifest disagree; manifest wins)
