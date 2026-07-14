# 040 — mpv open rejects working CDN mp4/HLS URLs

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** playback / player

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **4 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I40-T01 | Stop comma-joining `http-header-fields` (breaks Chrome UA); rely on `Media.httpHeaders` NODE_ARRAY | ✅ |
| 2 | I40-T02 | Always apply browser `User-Agent` + normalize trailing `.mp4/` URLs; shared `openPlayerStream` | ✅ |
| 3 | I40-T03 | FSST extractor ships embed `Referer`/`Origin`; probe uses same resolved headers | ✅ |
| 4 | I40-T04 | Open-wait treats HTTP/CDN failures as fatal; remote timeout 25s | ✅ |
| 5 | I40-T05 | Clear sticky mpv `referrer` on source switch; no double-resolve drop; external player shares resolve | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I40-A01 | Direct CDN MP4/MKV that opens in a browser/mpv CLI opens in Forja with default UA | ✅ |
| 2 | I40-A02 | VidSrc HLS with comma-containing UA still gets intact headers via media_kit | ✅ |
| 3 | I40-A03 | Unit + FSST golden/FFI cover URL normalize + header resolve | ✅ |
| 4 | I40-A04 | Extractor Referer wins over CDN-origin fallback; Cookie/Auth forwarded; sticky referrer cleared | ✅ |

---

## Summary

HTTP probe said streams were alive, but mpv `Failed to open` / timed out. Causes:

1. In-app `http-header-fields` joined with commas — Chrome UAs contain commas and corrupt the list.
2. Direct FSST/KinoGer MP4s often had **no** headers; mpv default `libmpv` UA is blocked by CDNs that allow browsers.
3. Trailing slash after extensions (`…/file.mp4/`) trips demuxers.

**Root fix:** `resolvePlaybackHttpHeaders` + `openPlayerStream` (browser UA, URL normalize, `Media.httpHeaders` only) and FSST Referer/Origin.
