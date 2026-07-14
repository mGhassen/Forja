# 051 — Embed multi-server sniff, proxy body, cookies

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `StreamExtractor` / `HostProviderAdapter` (Flutter WebView extraction)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I51-T01 | Auto-click internal server chips (VidLove Neta/Gogo/Mafia/Fabric and similar) during sniff | ✅ |
| 2 | I51-T02 | Parse `/api/proxy`, `/api/sources`, and XHR/fetch bodies for embedded `.m3u8` (VidSrc.sbs / 1embed) | ✅ |
| 3 | I51-T03 | Harvest WebView cookies into playback headers; prefer embed Referer over CDN FRAME | ✅ |
| 4 | I51-T04 | Defer early-complete for `vidlove` / `vidsrc.sbs` / `1embed`; `forceDirect` + embed referer for those hosts | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I51-A01 | VidLove HOTD S1E1: sniff detects `.m3u8` and player opens (probe + progress) | ⬜ |
| 2 | I51-A02 | VidSrc.sbs HOTD S1E1: `VIDEO/STREAM DETECTED` (not only proxy/blob) then opens | ⬜ |
| 3 | I51-A03 | Multi-server chips: sniffer logs server-chip clicks; default LOADMAXING does not strand forever | ⬜ |

---

## Summary

Browser works because users (or the page) pick a working internal server and the player keeps session cookies + correct Referer. Forja’s headless sniffer only clicked play overlays, ignored `/api/proxy` bodies without `.m3u8` in the URL, and opened CDN playlists with UA/Referer/Origin only (no Cookie). VidSrc.sbs nested into `1embed.cc` and never produced `VIDEO/STREAM DETECTED`. VidLove sometimes detected HLS then failed probe/open without cookies.

---

## Related

- [048](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) — `forceDirect` for iframe “Playback Restricted” (kept; extended here)
- [041](fixed/041-[fixed]-videasy-hangs-before-cdn-yoru.md) — similar “wrong first server” pattern
