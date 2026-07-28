# 117 — Android Live Matches: embedindia PPV stuck / black after handoff

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android / Android TV · Live Matches · PPV `embedindia.st` + Streamed Exo handoff

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I117-T01 | Do not leave embedindia on in-page WebView-only (CORS/lock) — use sniff → native like Streamed | ✅ |
| 2 | I117-T02 | ExoPlayer: set `APPLICATION_M3U8` for `/hls-proxy` / `.m3u8` / `strmd.st` (was Progressive → UnrecognizedInputFormat) | ✅ |
| 3 | I117-T03 | Handoff: origin Referer + WebView Cookie harvest; broader sniff; sandbox strip in all frames | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I117-A01 | Android TV: open a live PPV `embedindia` match → native IPTV shows video (not “Connecting…” forever / red sandbox lock) | ⬜ |
| 2 | I117-A02 | Android TV: open a live Streamed match → Exo (or MediaKit) shows video, not black / Source error | ⬜ |
| 3 | I117-A03 | Back from that player returns to Live Matches; audio stops | ⬜ |

---

## Summary

**Streamed black screen (logs):** Handoff opened `http://127.0.0.1:…/hls-proxy?url=…`. Exo’s `DefaultMediaSourceFactory` saw no `.m3u8` in the path → **ProgressiveMediaSource** → `UnrecognizedInputFormatException` on the playlist body. MediaKit can demux HLS from the same URL; Exo needs an explicit `MimeTypes.APPLICATION_M3U8`.

**PPV sandbox / Connecting…:** Leaving embedindia in the WebView (I117 first slice) still hits System WebView CORS / host-lock UI. Sniff timed out because the player never exposed a matching URL / sandbox strip ran main-frame-only. Correct path: sniff → local HLS proxy with **Referer + Cookie**, then native player (same as Streamed).

**Related:** [116](116-[open]-android-tv-live-matches-embed-cors-native-handoff.md)
