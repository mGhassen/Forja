# 476 — Continue Watching drops show when next episode is under 2%

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** playback / Continue Watching (hubs + Home)  
**Reported:** 2026-10-24 (Android TV · Asian Drama)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I476-T01 | Shared eligibility: `showStarted` keeps unfinished show under 2% floor | ✅ |
| 2 | I476-T02 | Hub `WatchHistory.record`: set/keep `showStarted` once show was CW-eligible | ✅ |
| 3 | I476-T03 | Home `WatchHistoryService` save + up-next seed write `showStarted` | ✅ |
| 4 | I476-T04 | Unit tests for `showStarted` eligibility + pool | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I476-A01 | Asian Drama: finish ep → start next → CW shows that show/ep before 2% | ⬜ |
| 2 | I476-A02 | Jump mid-show ep A (in progress) → ep B from 0 → CW stays on ep B | ⬜ |

---

## Problem

Finish an episode (up-next seeds the next ep). Start the next episode. Continue Watching hides the show until progress hits the 2% floor — CW is show-scoped, so once a series is started it must stay on the rail.

## Root cause

Eligibility was **2–85% or `upNext` only**. Starting the next ep clears `upNext` on the first heartbeat/seed and writes progress under 2% → row drops.

## Fix

Persist `showStarted` once a show is CW-eligible (in-progress, up-next, or prior eligible row). Eligibility treats `showStarted` as keep-until-finished (≥85%), so later episodes need no 2% wait.

## Links

- [454-[fixed]-continue-watching-drops-finished-episode.md](454-[fixed]-continue-watching-drops-finished-episode.md)
