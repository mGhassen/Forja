# 117 — Android Live Matches: embedindia PPV stuck / black after handoff

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android / Android TV · Live Matches · PPV `embedindia.st` + Streamed Exo handoff

## Status at a glance

| | |
|--|--|
| **Progress** | **21 / 21** fix · **0 / 3** acceptance |

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
| 10 | I117-T10 | Android PPV: top-level embedindia + Referer (no ppv.is iframe); Ajax/Fetch intercept PPV-only; drop probe URL blacklist | ✅ |
| 11 | I117-T11 | Keep handoff cover until route exit; mute sniffer WebView (no mid-probe JW PiP / audio leak) | ✅ |
| 12 | I117-T12 | Stop probe soft-recover loop; force-exit on abandon; Streamed catalog Referer on `/hls-proxy` | ✅ |
| 13 | I117-T13 | Disable InAppWebView Fetch/Ajax intercept on PPV (reused Request kills JW); spy clones Request | ✅ |
| 14 | I117-T14 | Split Android handoff: `LiveEmbedAndroidHandoffProfile` (PPV ≠ Streamed load/headers/soft-recover) | ✅ |
| 15 | I117-T15 | Restore Streamed probe: catalog Referer first + 450ms settle + 3 attempts (T14 speed tweak caused ATV 403) | ✅ |
| 16 | I117-T16 | PPV play gate: mute-first JW `play()` + center tap + playlist scrape; 1s sniff poll; cover `IgnorePointer` | ✅ |
| 17 | I117-T17 | Streamed redesign: capture `#EXTM3U` body from WebView → local file + Exo headers (no `/hls-proxy` re-GET/probe) | ✅ |
| 18 | I117-T18 | Streamed: WebView-backed loopback proxy for Exo (CDN fetch stays in Chromium; keep embed route mounted) | ✅ |
| 19 | I117-T19 | Re-enable Streamed Android native handoff; do not set `_exiting` before playlist body; Dart/Cookie seed + `/hls-proxy` fallback; peel nested embedindia | ✅ |
| 20 | I117-T20 | Streamed WebView proxy: fetch CDN with `credentials:omit` first (CDN ACAO:* forbids include → child m3u8 timeout / Exo reconnect) | ✅ |
| 21 | I117-T21 | Streamed: do not Dart-seed inside `shouldInterceptRequest` (blocks Chromium + always 403); seed playlist via WebView fetch before `/hls-proxy` | ✅ |

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

**PPV stuck + Streamed broke again (I117-T10):** Logs showed `embedindia.st` blocked from reading `flutter_inappwebview` on parent `ppv.is`, then sniff + StreamExtractor never saw m3u8. Ajax/Fetch intercept on **all** Android live embeds also broke Streamed XHR; probe-fail URL blacklist blocked the warm retry. Fix: Android PPV loads **top-level** embedindia with catalog `Referer` (cover still hides WebView); Ajax/Fetch hooks **PPV-only**; soft recover retries the same URL without blacklisting.

**Mid-handoff double video (I117-T11):** Sniff success set `_androidHandoffStarted` which **removed** the black cover before Cookie probe + `pushReplacement`. JW’s multi-cam PiP painted under Flutter chrome. Fix: keep the cover for the whole Android sniffer route; mute play nudges.

**Probe loop / Back stuck / process kill (I117-T12):** Soft-recover give-up reset `_exiting` while WebView kept re-sniffing the same `strmd.st` playlist → infinite handoff. `_exitPlayer` no-op’d while `_exiting` was true (Back looked broken); mashing Back on the nav rail then hit ATV double-Back exit (`finish` + kill). Fix: abandon flag stops sniff; one soft recover then toast + `force` pop; Streamed proxy Prefer catalog `Referer` (`streamed.pk`).

**PPV fetch broken (I117-T13):** Console `Cannot construct a Request with a Request object that has already been used` from embedindia — InAppWebView `shouldInterceptFetchRequest` wrapper. Disabled Fetch/Ajax intercept; sniff via `shouldInterceptRequest` + media spy (Request.clone).

**Cross-contamination (I117-T14):** PPV and Streamed share one embed player but fail differently. Fixes for one kept applying to both. Added `LiveEmbedAndroidHandoffProfile` — PPV: top-level load, full-embed Referer, soft-recover 0; Streamed: catalog iframe. Shared only cover + `/hls-proxy` + Exo. (T14 also shipped a Streamed “speed” tweak that T15 reverts.)

**Streamed ATV 403 again (I117-T15):** After T14, Streamed probed with **embed-origin Referer first**, **120ms** cookie settle, and only **2** attempts. Logs: sniff OK → `/hls-proxy` probe `403 Forbidden` ×4 → abandon. Restore T12/T09 path: catalog `streamed.pk` Referer on attempts 1+3, 450ms settle, 3 probes.

**PPV play gate (I117-T16):** Browser works after clicking JW big-play; ATV cover blocked that. Sniff timed out with `Uncaught (in promise)` and StreamExtractor only saw the embed page URL. Fix: mute-first `jwplayer().play()` + synthetic center tap + broader JW selectors; scrape `getPlaylist` / page HTML for `indianservers` / `.m3u8` before play; 1s poll; cover `IgnorePointer` so phone taps reach the WebView.

**Streamed redesign (I117-T17):** Referer/settle tweaks still re-GETted `strmd.st` via Rust and hit 403. New path: JS spy forwards the `#EXTM3U` **body** WebView already downloaded → write local `file://…/playlist.m3u8` (absolute segment URIs) → Exo opens that file with catalog Cookie/Referer for CDN segments. **No** `/hls-proxy` probe gate for Streamed.

**Streamed WebView proxy (I117-T18):** Captured-file + Exo headers still 403'd on CDN child playlist/segments (OkHttp ≠ Chromium). Exo now plays `http://127.0.0.1/playlist.m3u8`; every upstream URI is fetched **inside** the still-mounted embed WebView and returned over loopback.

**Streamed ATV sandbox lock again (I117-T19):** A mid-slice regression turned Streamed native handoff **off** (WebView-only). Logs: `strmd.st` CORS from `embed.st` + red **Remove sandbox attributes…** UI with Flutter pause/mute chrome. Fix: handoff on for all Android Live embeds again; wait for `#EXTM3U` **before** `_exiting` (URL sniff used to block body capture); seed playlist via Dart+cookies / intercept ACAO; fall back to `/hls-proxy` when body never lands; peel nested `embedindia` under `embed.st`.

**Streamed buffers then Reconnecting (I117-T20):** Master playlist captured and Exo opened on loopback, but child `…/high/mono.m3u8` fetch via the embed iframe used `credentials:include` while the CDN returns `Access-Control-Allow-Origin: *` — browser blocks that combo → proxy timeout → Exo reconnect loop. Fix: proxy fetch tries `credentials:omit` first (URL already carries the secure token), then `include`; empty CORS fails settle in 1.2s instead of hanging 20s.

**Streamed body + /hls-proxy exhausted (I117-T21):** Sniff fired from `shouldInterceptRequest`, which then **awaited** a Dart/OkHttp cookie re-GET of `strmd.st` (always 403) before returning null. That blocked Chromium’s own playlist download until handoff had already timed out waiting for `#EXTM3U`, then Dart seed + `/hls-proxy` also 403 → abandon. Fix: observe-only intercept (return null immediately); if the JS spy still misses the body, seed via Chromium `fetch` in the embed iframe before the OkHttp fallbacks.

**Player button:** The in-player **Player** control (Exo ↔ MediaKit / external) lives on `IptvPtPlayerScreen` after handoff — it does not appear on the WebView “Opening stream…” cover.

**Related:** [116](116-[open]-android-tv-live-matches-embed-cors-native-handoff.md)
