# 309 — Android TV Home: D-pad ↓ dies on Popular

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · Home hub · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I309-T01 | Hub CatalogBody cacheExtent so below-fold Mood / Because mount and register | ✅ |
| 2 | I309-T02 | Coordinator: ↓ with no next registered row nudges hub scroll + retries focus | ✅ |
| 3 | I309-T03 | PackLayoutPainter binds page scroller; ladder test for scroll-then-land | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I309-A01 | Android TV Home: ↓ from Popular lands on Continue (if any) or Mood chips | ⬜ |
| 2 | I309-A02 | Further ↓ reaches Because shuffle → Because rail → New Releases | ⬜ |
| 3 | I309-A03 | Widget: last-row ↓ with page scroller registers neighbor and focuses it | ✅ |

---

## Summary

Home D-pad walked hero → Featured → Popular, then **↓ stayed on Popular** while keys kept logging. Sort-order ladder tests passed when every row was already registered; live Home only registered on-screen slivers (default `CustomScrollView` cache ~250px). Mood / Because / lazy New Releases sat below the fold unregistered, so `moveVerticalInTab` hit “no next row” and **swallowed ↓**.

**Root fix:** Larger hub `cacheExtent` so eager sections register early, plus a tab page scroller: when ↓ has no registered neighbor, nudge the hub scroll (activates `LazyViewportGate`) and retry focus on the next row.

### Related

- [catalog_focus_ladder_test.dart](../../../apps/forja/test/catalog_focus_ladder_test.dart)
- [265](../265-[open]-android-tv-live-sports-dpad-down-from-shelf-portal.md) — lazy row scroll-into-view
- [home feature](../../features/movies-tv/home.md)
