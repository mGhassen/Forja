# RFC-055 — Native YouTube trailer player

**Status:** open  
**Depends on:** —  
**Area:** Playback / trailers

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **6 / 8** acceptance |
| **Current slice** | Native player + ATV D-pad chrome — device smoke remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-C01 | `YoutubeStreamService.resolveStreams` (youtube_explode, ANDROID_VR, isolate) | ✅ |
| 2 | R55-C02 | `TrailerPlayerScreen` plays via media_kit `BoxFit.contain` (no iframe / overscan) | ✅ |
| 3 | R55-C03 | Quality / captions / rate menus wired to resolved streams + media_kit | ✅ |

---

## Acceptance (native trailer slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A01 | Trailer opens: video fits viewport (letterbox/pillarbox OK), not zoomed past edges | ✅ |
| 2 | R55-A02 | No YouTube iframe chrome (logo / end-screen) — direct googlevideo playback | ✅ |
| 3 | R55-A03 | Play/pause, seek, volume, quality switch, captions (when present), next trailer | ✅ |
| 4 | R55-A04 | Exit tears down media_kit (no leftover audio) | ✅ |
| 5 | R55-A05 | Resolve failure shows retry + open-in-YouTube (no WebView fallback) | ✅ |
| 6 | R55-A06 | Desktop / TV smoke: Trailer from details plays contain-fit native video | ⬜ |
| 7 | R55-A07 | ATV D-pad: More videos ←/→/OK + ↑ Back; transport/seekbar neighbors; Back arms then exits | ✅ |
| 8 | R55-A08 | ATV device smoke: trailer D-pad + Back/Exit (`I154-A01`–`A03`) | ⬜ |

---

## Acceptance (ATV D-pad — issue 154)

Shipped under [issue 154](../issues/154-[open]-android-tv-trailer-player-dpad.md) (`I154-T01`–`T04`). Rows above: `R55-A07` code · `R55-A08` device smoke.

## Summary

Replace the fullscreen trailer YouTube iframe (and its 1.35× overscan hack to hide chrome) with Debrify’s path: resolve stream URLs via `youtube_explode_dart`, play in media_kit with `BoxFit.contain`.

## Goals

- Correct aspect fit — no deliberate zoom to clip YouTube UI
- No WebView in the fullscreen trailer player
- Quality ladder + VTT captions from resolve
- Details-hero ambient YouTube WebView deferred (out of this RFC slice)

## Contracts

- Default height cap: **1080p** H.264; VP9 listed above; AV1 excluded
- Prefer `YoutubeApiClient.androidVr` for googlevideo URLs that open in mpv
- Adaptive = video-only + separate AAC; muxed MP4 fallback
- Resolve off UI isolate; short TTL cache; re-resolve on open / trailer switch
- No iframe fallback on resolve failure

## Related

- [Media details](../features/movies-tv/media-details.md)
- [Issue 113](../issues/113-[open]-android-tv-trailer-player-white-screen.md) — WebView white screen (fullscreen path superseded)
- [Issue 154](../issues/154-[open]-android-tv-trailer-player-dpad.md) — ATV D-pad / Back / Exit
