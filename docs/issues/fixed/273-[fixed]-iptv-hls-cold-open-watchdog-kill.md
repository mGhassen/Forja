# 273 — IPTV HLS cold open killed by stall soft-reopen

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV · M3U · HLS · MediaKit watchdog

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I273-T01 | Hold empty-cache soft-reopen during HLS cold open (30s ABR grace) | ✅ |
| 2 | I273-T02 | Treat network-feeding / HLS cold open as `_streamWorking` (stall mode) | ✅ |
| 3 | I273-T03 | `demuxer-lavf-o` `+igndts` for DAI pts&lt;dts stalls | ✅ |
| 4 | I273-T04 | Unit test + changelog + feature doc | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I273-A01 | CBS News 24/7 (DAI) opens without `recovery … buffering 5s, cache empty` mid ABR probe; picture within ~30s | ⬜ |
| 2 | I273-A02 | Xtream progressive TS empty underrun still soft-reopens at ~5s (no HLS grace) | ⬜ |

---

## Summary

After [272](272-[fixed]-iptv-hls-m3u-continuity-proxy-death-spiral.md) skipped the TS proxy for `.m3u8`, MediaKit still failed on playable DAI channels (CBS News). ffmpeg was downloading variants/segments (`Invalid timestamps` / SCTE CUE-OUT) while demuxer cache stayed `0`. Stall recovery treated that as dead at **5s** and soft-reopened → `mbedtls_ssl_handshake` fail → forever Buffering.

**Root fix:** do not soft-reopen during HLS cold open; ignore bad DTS with `+igndts`. Geo-blocked Amagi/CloudFront channels (most XUMO from outside the US) remain upstream 403 — not this bug.
