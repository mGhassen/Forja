# 405 — Kurage Sources hover status hangs then red

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** `forja-packs/providers/kurage.js` · Sources hover probe

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I405-T01 | Kurage stream rows declare `probe: headOrRange` (progressive MP4 proxy) | ✅ |
| 2 | I405-T02 | Host playlist heuristic no longer treats every `/api/proxy` URL as HLS; HEAD and Range race | ✅ |
| 3 | I405-T03 | Issue + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I405-A01 | Anime Sources → Kurage row: hover status goes green in ~1s on a title that already plays | ⬜ |

---

## Summary

Kurage extract returns `https://kurage.live/api/proxy/…` with `Content-Type: video/mp4`. Playback works. Hover status used the default probe: any `/api/proxy` URL was treated as HLS (`GET` until `#EXTM3U`), then HEAD (hangs ~8s on this proxy) before Range (206). Result: long wait, then red.

**Root fix:** pack sets `probe: headOrRange`. Host playlist check is `.m3u8` / `/hls-proxy` only. HEAD and Range run together so a hanging HEAD does not block a fast 206.

Providers pack **1.6.28**.

### Related

- [218](218-[fixed]-dimatoon-green-play-probe-false-fail.md) — CDN HEAD false-fail vs play
