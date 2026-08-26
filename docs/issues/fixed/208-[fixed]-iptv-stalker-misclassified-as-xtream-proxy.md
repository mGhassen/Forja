# 208 — IPTV Stalker live misclassified as Xtream (continuity proxy)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV · Stalker · MediaKit continuity proxy

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I208-T01 | Map portal platform → `IptvLiveSourceKind` (`stalker` → no continuity proxy) | ✅ |
| 2 | I208-T02 | Wire `singleStream` / `fromHits` / browser live open (+ guide zap source tag) | ✅ |
| 3 | I208-T03 | Unit test + feature doc + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I208-A01 | Stalker live open logs `direct open (IptvLiveSourceKind.iptvStalker)` — no `[IPTV Proxy]` | ⬜ |
| 2 | I208-A02 | Xtream live still logs `continuity proxy (IptvLiveSourceKind.iptvXtream)` | ⬜ |

---

## Summary

IPTV catalog `singleStream` / `fromHits` never set `liveSourceKind`. The player defaulted `BuiltInPlayerContext.iptv` → `iptvXtream`, so Stalker `create_link` URLs (`live.php?mac=…&play_token=…`) ran through the localhost TS continuity proxy. Proxy re-GETs the same short-lived token → EOF / Failed to open / Failed to recognize file format / underrun loop.

**Root fix:** pass `portalPlatform` (or per-hit platform) into the player so Stalker uses `iptvStalker` (direct open). Forja Sports already tagged correctly.
