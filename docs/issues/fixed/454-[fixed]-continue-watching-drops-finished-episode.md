# 454 — Continue Watching drops show when an episode finishes

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** playback / Continue Watching (Home + hubs)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I454-T01 | Shared CW eligibility: in-progress (2–85%) **or** `upNext` seed | ✅ |
| 2 | I454-T02 | On ≥85% auto-mark: seed next aired hub / TMDB episode into CW | ✅ |
| 3 | I454-T03 | Card copy shows next ep (Up next); resume opens that ep from 0 | ✅ |
| 4 | I454-T04 | Unit tests for eligibility + next-ep seed helpers | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I454-A01 | Anime: finish mid-season ep → CW shows same title as next ep; last ep of show drops | ⬜ |
| 2 | I454-A02 | Home TV: finish S1 last ep with S2 aired → CW advances to S2E1 | ⬜ |

---

## Problem

Finishing an episode (≥85% auto-mark) removes the title from Continue Watching even when later episodes or seasons exist. Example: *Chillin' in Another World* S1E12 marked watched → Anime CW empty for that show.

## Root cause

CW only lists rows in the **2–85%** progress window. A finished episode falls out of that window, and nothing seeds the **next** episode into history.

## Target

Finish ep N → if a next aired episode exists, CW becomes that episode (up-next, start from 0). Last episode of the show → leave CW (show done).

## Fix

On first ≥85% auto-mark, seed the next aired episode into hub `WatchHistory` / Home `WatchHistoryService` with `upNext: true`. Continue Watching eligibility includes those seeds. Finished last episode still drops off.
