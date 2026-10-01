# 334 — MovieBox empty Sources (no visitor login / stale unwrap)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/moviebox.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I334-T01 | Probe live aoneroom API — confirm search/get/play-info return 441 without visitor-login; response is single `data` (not `data.data`) | ✅ |
| 2 | I334-T02 | visitor-login + Bearer on all calls; `play-info/v2` (+ resource fallback); host pool; fix unwrap; prefer exact title match | ✅ |
| 3 | I334-T03 | Providers pack 1.6.7 + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I334-A01 | Live probe: Inception → visitor-login → search → `play-info/v2` returns ≥1 stream URL | ✅ |
| 2 | I334-A02 | App: Sources → MovieBox lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

MovieBox Forja signed requests but never called **visitor-login**. The aoneroom API now returns **441** on search / subject get / legacy `play-info` without a Bearer token, so extract always ended empty. The parser also expected a double-nested `data.data` payload; live responses use a single `data` object (`results` / `streams`).

### Fix

- `POST /user-api/visitor-login` first; send `Authorization: Bearer …` on later calls
- Prefer `play-info/v2`, fall back to `play-info` then `resource`
- Rotate API hosts (`api6` … `api3`, `api.inmoviebox.com`)
- Unwrap `data` correctly; prefer exact English title over dubbed variants
- Providers pack **1.6.7**

### Related

- [055](055-[fixed]-vidnest-moviebox-referer-429.md) — MovieBox CDN Referer 429 (playback headers; separate)
- [stream providers](../../features/sources/stream-providers.md)
