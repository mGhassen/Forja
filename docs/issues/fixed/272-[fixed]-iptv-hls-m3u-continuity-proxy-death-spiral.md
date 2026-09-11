# 272 — IPTV HLS M3U channels fail via TS continuity proxy

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV · M3U · HLS · continuity proxy

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I272-T01 | Gate continuity proxy with `iptvShouldUseContinuityProxy` (skip `.m3u8`) | ✅ |
| 2 | I272-T02 | Unit tests for HLS skip + progressive TS still proxied | ✅ |
| 3 | I272-T03 | Feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I272-A01 | XUMO / HLS M3U channel open logs `direct open` — no `[IPTV Proxy] overlap skip incomplete` loop | ⬜ |
| 2 | I272-A02 | Xtream progressive TS live still logs `continuity proxy (IptvLiveSourceKind.iptvXtream)` | ⬜ |

---

## Summary

M3U portals map to `iptvXtream`, which enabled `IptvLiveContinuityProxy` for every live URL. Public HLS playlists (e.g. [apsattv xumo.m3u](https://www.apsattv.com/xumo.m3u) → CloudFront / DAI `.m3u8`) return a few KiB then EOF. The proxy treated that as a TS socket close, planned a 0.5 MiB overlap skip, saw EOF again (`left=510KiB`), and looped forever with `cache=0.0s feeding=false`.

**Root fix:** open HLS (`.m3u8`) direct; keep the continuity proxy for progressive MPEG-TS only.
