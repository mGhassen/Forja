# 316 — Hub catalog row prefetch skips host sections

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** `LazyViewportGate`, `KitRowPrefetchLane`, hub catalog scroll  
**Reported:** 2026-09-23

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I316-T01 | Eager + Continue/Mood/Because join the prefetch lane and notify when visible | ✅ |
| 2 | I316-T02 | Late-mounted gated rows inside the ahead window warm on claim | ✅ |
| 3 | I316-T03 | Prefetch warm activates only (no notify cascade); unit tests | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I316-A01 | On Because, New Releases has already started loading (two-row ahead) | ✅ |
| 2 | I316-A02 | First-paint/eager rails still paint immediately (no skeleton flash) | ✅ |
| 3 | I316-A03 | `kit_row_prefetch_test` covers late claim + ahead window | ✅ |

---

## Summary

Prefetch claimed to warm `kKitRowPrefetchAhead` (2) rows below the visible one, but only `LazyViewportGate` participated. Home **Continue / Mood / Because** skip the gate (host mounts), and first-paint rails skipped it when eager — so nothing called `notifyVisible` before **New Releases**. That gated rail only fetched when it itself entered the viewport.

**Root fix:** eager + host sections still claim lane indices and notify on visibility; late-mounted gates inside the ahead window warm on claim; prefetch warm no longer cascades `notifyVisible` (exact ahead=2).

**Follow-up:** genre rows under New Releases still stayed cold when prefetch `setState` dropped `VisibilityDetector` — [325](325-[fixed]-home-genre-rows-under-new-releases-not-prefetched.md).
