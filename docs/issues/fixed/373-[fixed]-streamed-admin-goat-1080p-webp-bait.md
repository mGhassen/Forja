# 373 — Streamed admin goat opens 1080p WebP bait (PPV / MediaKit completed spiral)

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Live Sports · Streamed · GOAT unlock · MediaKit  
**Reported:** 2026-09-24  
**Related:** [320](320-[fixed]-streamed-claims-ppv-catalog-goat-slot.md) · [no-embed-playback](../../.cursor/rules/no-embed-playback.mdc)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I373-T01 | Pack: `selectPlayableM3u8` walks master variants; pin highest playable media playlist | ✅ |
| 2 | I373-T02 | Streamed admin (and shared goat / GASM resolve) use select — not master-first | ✅ |
| 3 | I373-T03 | Host Dart `LiveGoatUnlock.selectPlayableM3u8` for sportsembed / GASM accept | ✅ |
| 4 | I373-T04 | Changelog — Streamed / PPV admin goat plays instead of reconnect death spiral | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I373-A01 | Manual: Streamed admin row for a live PPV slug (e.g. Netherlands vs Germany) plays video; no `live glitch (completed)` → goLive exhausted loop | ⬜ |

---

## Summary

**Symptom:** Unlock succeeded (`[LiveGoatUnlock] … streams=1`) but MediaKit never painted (`VideoOutput` 0×0), then `live glitch (completed)` → goLive unstable → exhausted. Same event plays in the web player.

**Root:** Admin goat masters list **1080p first** with TikTok CDN **WebP** segments, then **540p** with real MPEG-TS on `lb*.strmd.st`. MediaKit picks highest bandwidth and dies on WebP. Web ABR falls back to 540p.

**Fix:** After unlock, probe every variant and open the highest-bandwidth **playable** media playlist (typically `…/low/mono.m3u8`), not the bait master.
