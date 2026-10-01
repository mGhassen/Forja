# 296 — Simkl scrobble missing mid-episode progress

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** player / trackers (Simkl)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I296-T01 | `SimklService` scrobble start/pause/stop send required `progress` (0–100) | ✅ |
| 2 | I296-T02 | Desktop / mobile MediaKit + Exo call sites pass position/duration % | ✅ |
| 3 | I296-T03 | Unit test `progressPercent` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I296-A01 | Pause mid-episode → Simkl playback session shows that episode at ~same % | ⬜ |
| 2 | I296-A02 | Stop / exit ≥80% still marks episode watched via scrobble stop | ⬜ |

---

## Summary

Simkl scrobble bodies omitted `progress`, so pause/stop could not save mid-episode playback. Send `progress` from player position/duration on start, pause, and stop (MediaKit desktop/mobile + Exo).

Does **not** pull Simkl `/sync/playback` into Forja Continue Watching — write path only.
