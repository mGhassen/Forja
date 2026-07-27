# 116 — Android TV Live Matches: embed.st CORS / sandbox lock → native handoff

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Live Matches · Streamed `embed.st` WebView

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I116-T01 | Android Live embed: sniff `.m3u8` / `strmd.st` from visible WebView (resource + fetch/XHR spy) | ✅ |
| 2 | I116-T02 | Hand off sniffed HLS to `IptvPtPlayerScreen` via local proxy headers; cover lock UI while sniffing | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I116-A01 | Android TV: open a live Streamed match → native IPTV player shows video (not red “Remove sandbox attributes…”) | ⬜ |
| 2 | I116-A02 | Back from that player returns to Live Matches; audio stops | ⬜ |

---

## Summary

Streamed embeds under `embed.st` request HLS from `*.strmd.st`. In Android System WebView that fetch is **CORS-blocked** (`No Access-Control-Allow-Origin`), and the host lock UI shows the red **“Remove sandbox attributes on the iframe tag”** page (same copy as a sandboxed iframe — misdiagnosed in earlier Android top-level / frameElement patches). Desktop browsers can play in-page; ATV headless sniff is blocked ([031](031-[workaround]-android-tv-webview-gles-crash.md)).

**Symptom fix:** Visible WebView still loads the catalog iframe wrapper (referrer), sniffs the playlist URL, proxies it with embed Referer/Origin, and **pushReplacement** to the native IPTV/Exo player (no CORS).

**Root:** Third-party CDN CORS + WebView lock — cannot be fixed inside Chromium WebView without their ACAO headers. Native play is the correct product path on Android.

**Related:** [046](046-[open]-streamed-live-embed-white-screen.md) · [104](104-[open]-android-tv-live-matches-embed-dpad.md)
