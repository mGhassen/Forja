# 117 — Android Live Matches: embedindia PPV stuck / black after handoff

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android / Android TV · Live Matches · PPV `embedindia.st` + Streamed Exo handoff

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I117-T01 | Do not leave embedindia on in-page WebView-only (CORS/lock) — use sniff → native like Streamed | ✅ |
| 2 | I117-T02 | ExoPlayer: set `APPLICATION_M3U8` for `/hls-proxy` / `.m3u8` / `strmd.st` (was Progressive → UnrecognizedInputFormat) | ✅ |
| 3 | I117-T03 | Handoff: origin Referer + WebView Cookie harvest; broader sniff; sandbox strip in all frames | ✅ |
| 4 | I117-T04 | Harden sniff: JW/Hls hooks, postMessage iframe bridge, `shouldInterceptRequest`, periodic poll + play nudge | ✅ |
| 5 | I117-T05 | Sniff timeout: StreamExtractor fallback on phone; clear toast + exit on ATV (headless blocked) | ✅ |
| 6 | I117-T06 | `/hls-proxy`: forward Cookie/Authorization upstream; never rewrite non-`#EXTM3U` bodies as 200 m3u8 | ✅ |
| 7 | I117-T07 | Live Matches handoff forces Exo; probe playlist before open; one-shot Exo↔MediaKit swap on format error | ✅ |
| 8 | I117-T08 | PPV embedindia: Ajax/Fetch XHR sniff for `*.indianservers.st`; full-embed Referer on handoff; prefer master playlist | ✅ |
| 9 | I117-T09 | Streamed intermittent close: retry Cookie probe 3×; on fail resume sniff (do not pop player) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I117-A01 | Android TV: open a live PPV `embedindia` match → native IPTV shows video (not “Connecting…” forever / red sandbox lock) | ⬜ |
| 2 | I117-A02 | Android TV: open a live Streamed match → Exo (or MediaKit) shows video, not black / Source error / Reconnecting loop | ⬜ |
| 3 | I117-A03 | Back from that player returns to Live Matches; audio stops | ⬜ |

---

## Summary

**Streamed black screen (logs):** Handoff opened `http://127.0.0.1:…/hls-proxy?url=…`. Exo’s `DefaultMediaSourceFactory` saw no `.m3u8` in the path → **ProgressiveMediaSource** → `UnrecognizedInputFormatException` on the playlist body. MediaKit can demux HLS from the same URL; Exo needs an explicit `MimeTypes.APPLICATION_M3U8`.

**PPV sandbox / Connecting…:** Leaving embedindia in the WebView (I117 first slice) still hits System WebView CORS / host-lock UI. Sniff timed out because the player never exposed a matching URL / sandbox strip ran main-frame-only. Correct path: sniff → local HLS proxy with **Referer + Cookie**, then native player (same as Streamed).

**Sniff still timing out (I117-T04):** Visible WebView cover (“Opening stream…”) hid a dead sniff — fetch/XHR-only spy missed JW `playlist` / HLS.js `loadSource`, and cross-origin embed iframes could not `callHandler`. Hardened spy + Android `shouldInterceptRequest` + Dart poll/play nudge. Phone can fall back to StreamExtractor; ATV cannot (headless WebView blocked).

**Reconnect loop after sniff (I117-T06/T07):** Cookies were harvested into the proxy URL query JSON, but Rust `/hls-proxy` only forwarded User-Agent / Referer / Origin — **Cookie never reached the CDN**. Upstream HTML/403 was still rewritten as **200** `application/vnd.apple.mpegurl`, so MediaKit reported **Failed to recognize file format** and the IPTV watchdog showed **Reconnecting…** forever. Fix: forward Cookie, reject non-`#EXTM3U` bodies, force Exo on Live Matches handoff, probe before open, and one-shot engine swap on format errors.

**PPV still failing after Streamed worked (I117-T08):** embedindia JW loads `https://*.indianservers.st/secure/…/index.m3u8` via **XHR**. Streamed’s `strmd.st` path was visible to resource intercept; PPV XHR often was not. Ajax/Fetch intercept + `indianservers.st` sniff match + handoff Referer = full embed URL (not only origin/).

**Streamed intermittent close (I117-T09):** First open sometimes sniffed the playlist before WebView cookies settled → probe 403 → toast + pop. Retry worked because the session was warm. Fix: short settle delay, up to 3 Cookie re-harvest + probe attempts, then resume sniff instead of closing.

**Player button:** The in-player **Player** control (Exo ↔ MediaKit / external) lives on `IptvPtPlayerScreen` after handoff — it does not appear on the WebView “Opening stream…” cover.

**Related:** [116](116-[open]-android-tv-live-matches-embed-cors-native-handoff.md)
