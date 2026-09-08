# 212 — Android TV Sources Filters D-pad stuck per Wrap line

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Sources Filters panel · `TorrentSourceSearchToolbar` / `_TorrentFiltersSidePanel`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I212-T01 | Filters `TvOverlayScope`: `linear: true` so ←/→ walk reading order across Wrap runs | ✅ |
| 2 | I212-T02 | Filter chips: TV green focus chrome + `ensureVisible` item scroll | ✅ |
| 3 | I212-T03 | Replace linear wrap with per-section `TvKitRow` (`sources-filters` graph): → on last chip traps; ↓/↑ between Category / Quality / Size / … | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I212-A01 | ATV Sources → Filters: ←/→ stay inside a section; → on the last chip of a section does not jump to the next section; ↓/↑ move between sections | ⬜ |
| 2 | I212-A02 | Focused filter chip shows green chrome; OK toggles; Clear / Close reachable | ⬜ |

---

## Summary

Filters chips sit in a `Wrap` per section (Category, Quality, Size, Language, Tech, …). Spatial overlay D-pad dead-ended at the end of each visual Wrap run. I212-T01 briefly used reading-order linear traversal so → continued across runs — that also chained **sections** (Drama → 4K). Product intent is **independent sections**: ←/→ only within a section, → on the last chip traps, ↓/↑ moves to the neighboring section.

**Root fix (current):** `TvFocusGraph` + one `TvKitRow` per filter section on `sources-filters`; header Clear/Close as its own row; green chip chrome from T02.
