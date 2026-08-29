# 212 — Android TV Sources Filters D-pad stuck per Wrap line

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Sources Filters panel · `TorrentSourceSearchToolbar` / `_TorrentFiltersSidePanel`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I212-T01 | Filters `TvOverlayScope`: `linear: true` so ←/→ walk reading order across Wrap runs | ✅ |
| 2 | I212-T02 | Filter chips: TV green focus chrome + `ensureVisible` item scroll | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I212-A01 | ATV Sources → Filters: → at end of a chip row lands on the first chip of the next row; ← wraps upward | ⬜ |
| 2 | I212-A02 | Focused filter chip shows green chrome; OK toggles; Clear / Close reachable | ⬜ |

---

## Summary

Filters chips sit in a `Wrap`. Default overlay D-pad is spatial (`focusInDirection`), so each visual line is independent — → at the last chip of a run finds no right neighbor and stalls. Chips also painted no focus ring on TV (`accentHover` off).

**Root fix:** reading-order linear traversal on the Filters overlay + TV accent focus chrome on sheet chips.
