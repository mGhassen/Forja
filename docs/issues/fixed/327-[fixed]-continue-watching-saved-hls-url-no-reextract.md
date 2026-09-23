# 327 — Continue Watching opens saved HLS URL without re-extract

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/playback/open/engine_auto_play.dart`, watch history

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I327-T01 | Remove saved-URL open shortcut in `runEngineAutoPlay` (always re-extract preferred plugin) | ✅ |
| 2 | I327-T02 | Soft-prefer matching catalog row after extract; keep `startPosition` seek | ✅ |
| 3 | I327-T03 | Persist durable catalog URL in watch history (unwrap `/hls-proxy`) | ✅ |
| 4 | I327-T04 | Token expiry unwraps proxy + honors `expires=` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I327-A01 | Continue Watching shows loading overlay, re-extracts last provider, then seeks | ✅ |
| 2 | I327-A02 | Feature docs + changelog describe re-extract resume (not saved-URL probe) | ✅ |

---

## Summary

Continue Watching / Resume pinned the last Forja provider and **opened the saved play URL** when a master HTTP probe passed (`pinSource: true`, no sources list). History often stored session `/hls-proxy?url=…` links. Cold open at resume offset failed; re-clicking the same row in Sources (fresh probe, open from ~0) worked.

### Fix

- Drop the saved-URL shortcut — resume always runs the loading overlay + preferred-plugin extract/probe race, then opens with `startPosition`
- Soft-prefer a matching catalog identity after extract (nested proxy unwrap)
- Watch history stores durable catalog URLs, not loopback play URLs
- `isStreamUrlTokenExpired` unwraps `/hls-proxy` and checks `expires=`

### Related

- [043](043-[fixed]-dead-cache-full-auto-reresolve.md) — dead cache full Auto re-resolve
- [Watch history](../features/movies-tv/watch-history.md) · [Direct streaming](../features/movies-tv/direct-streaming-mode.md)
