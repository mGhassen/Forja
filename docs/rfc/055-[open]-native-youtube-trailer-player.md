# RFC-055 — Native YouTube trailer player

**Status:** open  
**Depends on:** —  
**Area:** Playback / trailers

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **34 / 40** acceptance |
| **Current slice** | One resolve; proxy pipes those GVS URLs — smoke remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-C01 | `YoutubeStreamService.resolveStreams` (youtube_explode, ANDROID_VR, isolate) | ✅ |
| 2 | R55-C02 | `TrailerPlayerScreen` plays via media_kit `BoxFit.contain` (no iframe / overscan) | ✅ |
| 3 | R55-C03 | Quality / captions / rate menus wired to resolved streams + media_kit | ✅ |
| 4 | R55-C04 | HLS-first resolve (Safari/iOS muxed m3u8) + googlevideo fallback | ✅ |
| 5 | R55-C05 | DASH itag 137 + AAC: `audio-file` before open (no post-open audio-add); HLS path removed | ✅ |
| 6 | R55-C06 | Desktop: spawn yt-dlp ≥2026 (download official binary if needed); play local A+V files | ✅ |
| 7 | R55-C07 | Loopback `/v`+`/a`: C# `range=` windows, stream to mpv (no full-file download, no yt-dlp) | ✅ |

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
| 2 | R55-A18 | Adaptive Quality: androidVr-only resolve (no multi-client merge) + forceRefresh + open/play audio-add | ✅ |

---

## Acceptance (HLS-first)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A19 | Default open is Safari/iOS HLS muxed variant ≤1080p when YouTube offers HLS (not progressive 360p) | ✅ |
| 2 | R55-A20 | Quality switch reopens an HLS variant URL (no audio-add) | ✅ |
| 3 | R55-A21 | No HLS / HLS open fail → existing androidVr muxed/adaptive googlevideo (then embed) | ✅ |
| 4 | R55-A22 | Desktop/TV smoke: trailer ≥720p when YouTube HLS has it; Quality changes picture | ⬜ |
| 5 | R55-A23 | Default googlevideo open is adaptive ≤1080 (AVC preferred), not muxed 360p | ✅ |

---

## Acceptance (DASH audio-file)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A24 | Adaptive open binds AAC via mpv `audio-file` **before** `player.open` (no `setAudioTrack` after) | ✅ |
| 2 | R55-A25 | Desktop/TV smoke: trailer opens ≥720p with audio; Quality changes picture | ⬜ |

---

## Acceptance (yt-dlp GVS)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R55-A26 | Googlevideo bytes: Innertube UA (not Chrome), `identity` encoding, 10 MiB sequential Range clamped to clen-1; explode `get()` not used | ✅ |
| 2 | R55-A27 | Proxy walks tv / safari / mweb / ios / androidVr / sdkless / android / mediaConnect / default until AAC GVS returns 206 (not sdkless-first silent 1080p) | ✅ |
| 3 | R55-A28 | GVS/open 403 → Retry / Open in YouTube (not embed WebView); embed only for age-gate | ✅ |
| 4 | R55-A29 | Desktop: yt-dlp ≥2026 downloads adaptive ≤1080 + AAC (own Range/n-sig/POT); media_kit opens the files. Android/iOS keep explode proxy | ✅ |
| 5 | R55-A30 | Adaptive play is loopback stream: query `range=` 9898989 windows (C# MediaStream); mpv opens `/v` and `audio-add /a`; no yt-dlp file download | ✅ |
| 6 | R55-A31 | Never whole-file GVS GET; probe window 2; HTTP Range fallback on 403 so AAC/itag 140 is not silent | ✅ |
| 7 | R55-A32 | Proxy ignores isolate ANDROID googlevideo URLs; walks tv/safari until A+V windows 206 | ✅ |
| 8 | R55-A33 | Hostless/cipher-empty stream URIs skip that client; walk continues (no `GET ?range=` throw) | ✅ |
| 9 | R55-A34 | Adaptive bytes via explode `streamsClient.get(StreamInfo)` (no custom GVS); muxed 360p is not a fallback | ✅ |
| 10 | R55-A35 | Safari/WEB n-sig via explode ejs on flutter_js (no Deno binary); loopback `get()` those streams | ✅ |
| 11 | R55-A36 | GVS bytes are C# query `range=` + matching UA; dart `get()` remanifest ANDROID is not used (AAC was silent) | ✅ |
| 12 | R55-A37 | C# throttled window is `from+(9898989-1)` even past clen (do not clamp itag 140 to whole file) | ✅ |
| 13 | R55-A38 | AAC fetched first (~2 MB) then `/a` from memory; video GVS after (no parallel A+V) | ✅ |
| 14 | R55-A39 | AAC GVS 403 retries clamped query + HTTP Range then next client (trailer swap must not die) | ✅ |
| 15 | R55-A40 | Proxy does not `getManifest`; pipes isolate video+audio URLs (one C# `range=` window). Muxed last-resort if AAC 403 | ✅ |

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
- **Default open:** adaptive ≤1080 + AAC from the **one** isolate resolve (TV-first). Loopback pipes those googlevideo URLs — no second WEB/iOS/VR `getManifest` (that bot-checks and 403s AAC). AAC fetched first. If that GVS 403s, muxed progressive (≤360p) so the trailer still starts.
- Quality ladder is adaptive googlevideo heights from that resolve; Quality reopens another height from the cache (no re-resolve)
- explode `getManifest` HEAD probe is skipped (itag 137/271 403 used to drop the whole client)
- Resolve off UI isolate; short TTL cache; prefetch from details trailers / hero Trailer
- Captions fetched lazily when the CC menu opens (not on open)
- Age / unplayable native resolve → YouTube nocookie embed WebView fallback (Forja +18; no YouTube account)
- No iframe fallback on resolve failure **except** age/unplayable gate above

## Related

- [Media details](../features/movies-tv/media-details.md)
- [Issue 113](../issues/113-[open]-android-tv-trailer-player-white-screen.md) — WebView white screen (fullscreen path superseded)
- [Issue 154](../issues/154-[open]-android-tv-trailer-player-dpad.md) — ATV D-pad / Back / Exit
- [Issue 197](../issues/197-[open]-android-tv-trailer-quality-switch.md) — ATV quality switch
