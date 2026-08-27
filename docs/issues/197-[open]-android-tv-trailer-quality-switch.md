# 197 — Android TV trailer quality switch does nothing

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · trailer player · YouTube quality  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **26 / 26** fix · **0 / 2** acceptance |
| **Current slice** | One resolve; proxy pipes those GVS URLs — smoke remaining |

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
| 6 | I197-T06 | Default resolve adaptive-first (Debrify) — stop opening muxed 360p as playUrl | ✅ |
| 7 | I197-T07 | Muxed only as silent-audio fallback on first open; keep AAC for quality ladder | ✅ |
| 8 | I197-T08 | Prefetch + deferred captions so quality switch is not racing a cold resolve | ✅ |
| 9 | I197-T09 | Manifest clients include `tv` (+ sdkless/ios) so age-restricted trailers resolve | ✅ |
| 10 | I197-T10 | HLS-first resolve (Safari/iOS muxed m3u8); Quality reopens variant URL (no audio-add) | ✅ |
| 11 | I197-T11 | DASH itag 137 + AAC: bind `audio-file` before open (no post-open `setAudioTrack`); HLS path removed | ✅ |
| 12 | I197-T12 | GVS pipe: Innertube UA + 10 MiB clamped sequential Range (yt-dlp); no explode `get()` / Chrome UA | ✅ |
| 13 | I197-T13 | Walk tv/safari/mweb/ios/vr/sdkless/android/mediaConnect/default until AAC GVS 206 | ✅ |
| 14 | I197-T14 | Native open/GVS 403 → Retry (not embed WebView); embed only age-gate | ✅ |
| 15 | I197-T15 | Desktop trailers: yt-dlp ≥2026 downloads A+V (not explode GVS). Android TV unchanged | ✅ |
| 16 | I197-T16 | Remove yt-dlp download; stream A+V on loopback with C# query `range=` (desktop + ATV) | ✅ |
| 17 | I197-T17 | AAC/window-2 403: never whole-file GVS GET; probe 2 windows; HTTP Range on 403 | ✅ |
| 18 | I197-T18 | Do not pipe isolate ANDROID googlevideo URLs (1 KB 206 / whole itag 403); walk tv/safari | ✅ |
| 19 | I197-T19 | Cipher-empty / hostless stream URIs must not abort the client walk (`GET ?range=` throw) | ✅ |
| 20 | I197-T20 | Pipe explode `streamsClient.get(StreamInfo)` into loopback; do not fall back to muxed 360p | ✅ |
| 21 | I197-T21 | Safari/WEB n-sig via explode ejs on flutter_js (no Deno); `get(StreamInfo)` those URLs | ✅ |
| 22 | I197-T22 | Do not use dart `streamsClient.get()` (403 remanifest ANDROID + unclamped Range kills AAC); C# query `range=` + Innertube UA | ✅ |
| 23 | I197-T23 | C# window is `pos+9898989-1` (may exceed clen); GVS on explode HttpClient. Clamping itag 140 to `clen-1` was the AAC 403 | ✅ |
| 24 | I197-T24 | Prefetch AAC (~2 MB) before any video GVS; serve `/a` from memory (parallel A+V 403s itag 140) | ✅ |
| 25 | I197-T25 | AAC 403: retry clamped query + HTTP Range; next Innertube client (do not abort the trailer) | ✅ |
| 26 | I197-T26 | Do not remanifest in the proxy (WEB/iOS/VR walk bot-checks). Pipe isolate URLs; muxed only if AAC GVS 403 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I197-A01 | Android TV: open a trailer → Quality → pick another height — picture resolution changes (not stuck on first stream) | ⬜ |
| 2 | I197-A02 | Android TV: after quality switch, audio still present and position roughly resumes | ⬜ |

---

## Summary

Trailer **Quality** on Android TV updated the checkmark but playback stayed on the first googlevideo URL (or went silent). Logs showed `HTTP error 403 Forbidden` on quality reopen. Separately, default open preferred **muxed progressive** (~360p), so the menu often sat on 360 and failed switches recovered to that muxed stream.

**Root cause (stacked):**
1. **403:** `resolvePlaybackHttpHeaders` derived googlevideo self-Referer → CDN reject on reopen.
2. **False open fail:** after `resetPlayerForOpen`/`stop()`, mpv abort noise (`HTTP error` / `Failed to open`) made `waitForPlayerStreamOpen` settle false immediately — adaptive quality never stuck; recovery reopened muxed **360p**.
3. **Stale audio tracks** on ATV MediaCodec without forced `audio-add`.
4. **Muxed-first default** (Forja divergence from Debrify) — playUrl was progressive ≤360p; quality ladder was adaptive-only.

**Fix:** strip googlevideo Referer/Origin; trailer reopen polls `isMediaOpenReady` without fatal error settle; quality switch always `forceAudioAdd`; adaptive-first resolve (Debrify) with muxed only as silent fallback; prefetch + lazy captions; failed switch recovers prior stream.

**Current:** Proxy is a byte pipe for the isolate resolve (`I197-T26`) — no second `getManifest`. Muxed ≤360p only if AAC GVS 403s. Device smoke still open (`I197-A01` / `A02`).

## Related

- [RFC-055](../rfc/055-[open]-native-youtube-trailer-player.md)
- [154](154-[open]-android-tv-trailer-player-dpad.md) — ATV trailer D-pad
- [Media details](../features/movies-tv/media-details.md)
