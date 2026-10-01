# 383 — Live Sports panel keeps the selected match on screen

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Live Sports · schedule cards

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I383-T01 | Docking the streams panel keeps the schedule list mounted (scroll state survives) | ✅ |
| 2 | I383-T02 | After cards reflow, scroll so the open match stays at the same place on screen | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I383-A01 | Widget test: narrowing the event grid keeps the selected card’s top; widening it again keeps that card | ✅ |
| 2 | I383-A02 | On device, a scrolled Cards match stays on screen when the streams panel opens and when it closes | ⬜ |

---

## Summary

Tapping a match opened the streams panel by swapping the schedule from a full-width grid into a 60/40 row. That remounted the list, so scroll went back to the top. Cards also reflowed into fewer, taller columns, so a preserved pixel offset still showed a different row.

**Root fix:** the schedule slot is always a row, so the grid’s scroll state stays. When card size or column count changes, the scroll offset is rewritten so the open match (or the match that just closed) stays the same distance from the top of the grid.

**Related:** [live-sports.md](../../features/live/live-sports.md)
