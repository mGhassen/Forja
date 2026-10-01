# 325 — Home genre rows under New Releases stay cold while scrolling

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `LazyViewportGate`, hub catalog scroll prefetch  
**Reported:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **5 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I325-T01 | After prefetch activate, re-check viewport intersection and `notifyVisible` | ✅ |
| 2 | I325-T02 | Scroll-position listener advances the ahead window when detector drops | ✅ |
| 3 | I325-T03 | Widget test: New Releases on screen warms the next genre gate | ✅ |
| 4 | I325-T04 | `kKitRowPrefetchAhead = 3` for every catalog row (uniform) | ✅ |
| 5 | I325-T05 | Scroll sync activates gated rows in viewport (not only already-activated) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I325-A01 | On New Releases, the next genre row has already started loading | ✅ |
| 2 | I325-A02 | Prefetch warm still does not cascade `notifyVisible` (no whole-page fetch) | ✅ |
| 3 | I325-A03 | `lazy_viewport_gate_prefetch_test` covers viewport notify after prefetch | ✅ |
| 4 | I325-A04 | On Continue, New Releases (3 ahead) has already started loading | ✅ |
| 5 | I325-A05 | Every visible hub row warms the next 3 gated rows the same way | ✅ |

---

## Summary

[316](316-[fixed]-hub-catalog-row-prefetch-skips-host-sections.md) made Continue / Mood / Because join the prefetch lane so **New Releases** warms two rows ahead. Warming New Releases does `setState` while it is scrolling on-screen; that can drop the in-flight `VisibilityDetector` callback, so New Releases never called `notifyVisible` and **genre rows under it stayed cold** until each entered the viewport.

**Root fix:** after prefetch activate (and on scroll), if the gate overlaps the scrollable viewport, call `notifyVisible` so the ahead window keeps advancing. **`kKitRowPrefetchAhead = 3`** for every catalog row the same way — Continue warms Mood + Because + New Releases; New Releases warms the next three genre slots when present.
