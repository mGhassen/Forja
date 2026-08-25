# RFC-055 — Native YouTube trailer player

**Status:** open  
**Depends on:** —  
**Area:** Playback / trailers

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **14 / 18** acceptance |
| **Current slice** | Muxed-first open + fast adaptive fail — device smoke remaining |

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
| 9 | R55-A09 | Trailer opens with audible audio (muxed default; adaptive uses audio-add fallback) | ✅ |
| 10 | R55-A10 | ATV: Quality menu switches googlevideo height (stop+reopen+audio-add); picture changes (`I197-A01`) | ⬜ |

---

## Acceptance (adaptive-first / Debrify parity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A11 | Default open is adaptive ≤1080p + AAC (not muxed 360p); muxed only if adaptive silent | ✅ |
| 2 | R55-A12 | Details trailers row + hero Trailer prefetch resolve (cache hit on open) | ✅ |
| 3 | R55-A13 | Captions fetched lazily on CC menu (not on critical open path) | ✅ |
| 4 | R55-A14 | Desktop/TV smoke: open trailer ≥720p when available; Quality changes picture | ⬜ |
| 5 | R55-A15 | Age-restricted trailers: getManifest tries androidVr + tv (+ sdkless/ios) so racyCheckOk unlocks streams | ✅ |
| 6 | R55-A16 | Age-gate / unplayable native resolve → YouTube embed WebView fallback (no sign-in; Forja +18) | ✅ |

---

## Acceptance (muxed-first restore)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A17 | Default open is muxed progressive when available (audible, no adaptive demux wait) | ✅ |
| 2 | R55-A18 | Adaptive Quality: open playing + audio-add (no pause-demux abort); fail → recover/muxed | ✅ |

---

## Acceptance (ATV D-pad — issue 154)

Shipped under [issue 154](../issues/154-[open]-android-tv-trailer-player-dpad.md) (`I154-T01`–`T04`). Rows above: `R55-A07` code · `R55-A08` device smoke remaining.

## Summary

Replace the fullscreen trailer YouTube iframe (and its 1.35× overscan hack to hide chrome) with Debrify’s path: resolve stream URLs via `youtube_explode_dart`, play in media_kit with `BoxFit.contain`.

## Goals

- Correct aspect fit — no deliberate zoom to clip YouTube UI
- No WebView in the fullscreen trailer player
- Quality ladder + VTT captions from resolve
- Details-hero ambient YouTube WebView deferred (out of this RFC slice)

## Contracts

- Default height cap: **1080p** H.264; VP9 listed above; AV1 excluded
- Prefer `YoutubeApiClient.androidVr` for googlevideo URLs that open in mpv; also try `tv` / `androidSdkless` / `ios` in the same manifest call (age / racy gate)
- **Default open:** muxed progressive when available (fast audible start); adaptive ladder for Quality menu; short adaptive demux/ready timeouts then muxed fallback
- Quality ladder is the full adaptive height list; desktop always `audio-add` after adaptive open; ATV prefers `audio-file` then `audio-add` if no track
- Resolve off UI isolate; short TTL cache; prefetch from details trailers / hero Trailer; re-resolve on open / trailer switch
- Captions fetched lazily when the CC menu opens (not on open)
- Age / unplayable native resolve → YouTube nocookie embed WebView fallback (Forja +18; no YouTube account)
- No iframe fallback on resolve failure **except** age/unplayable gate above

## Related

- [Media details](../features/movies-tv/media-details.md)
- [Issue 113](../issues/113-[open]-android-tv-trailer-player-white-screen.md) — WebView white screen (fullscreen path superseded)
- [Issue 154](../issues/154-[open]-android-tv-trailer-player-dpad.md) — ATV D-pad / Back / Exit
- [Issue 197](../issues/197-[open]-android-tv-trailer-quality-switch.md) — ATV quality switch
