# 043 — Dead cache must full Auto re-resolve like first Play

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/player/player/*_player_playback.dart`, webstreaming cache

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I43-T01 | After sibling streams fail: drop `WebstreamingStreamCache` for title | ✅ |
| 2 | I43-T02 | Auto: `_reresolveLikeFirstPlay` via `resolveAutoForMovie` (score order from top) | ✅ |
| 3 | I43-T03 | Pinned server: keep same-provider fresh extract then stop (Sources) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I43-A01 | Auto + dead cache: siblings → invalidate → full resolve race like green Play | ✅ |
| 2 | I43-A02 | Feature docs describe dead-cache recovery vs mid-play next-server hop | ✅ |

---

## Summary

Cached webstreaming lists could go stale (CDN expired). Sibling URLs were tried, but Auto then only walked **remaining** providers via `_autoFallbackToNextProvider` — not a fresh first-Play resolve from the top.

### Fix

- Desktop + mobile init path: after siblings fail → `WebstreamingStreamCache.drop` → Auto runs `PlayerSourceResolve.resolveAutoForMovie` (loading roulette) → open winner
- Pinned / Auto server Off: same-provider re-extract (existing), then stop with Sources message
- Mid-play decoder recovery may still use `_autoFallbackToNextProvider` (next in chain) — separate from dead-cache init recovery

### Related

- [037](../037-[open]-webstreaming-all-providers-open-validate.md) — open/probe + Auto pin policy
- [Player](../features/playback/player.md) · [Stream providers](../features/sources/stream-providers.md)
