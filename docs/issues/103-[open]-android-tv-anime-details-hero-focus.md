# 103 — Android TV anime details: missing hero data + focus chrome

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Anime details · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I103-T01 | Short/720p hero chrome floor + budget: keep title before dropping synopsis | ✅ |
| 2 | I103-T02 | Episode cards show focus border (selected \|\| focused), no scale | ✅ |
| 3 | I103-T03 | Anime details TV row sortOrder after seasons+episodes (no Related collision) | ✅ |
| 4 | I103-T04 | Trailer cards: focus border, `scaleOnFocus: 1.0` (no lift) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I103-A01 | Android TV anime details shows title (+ synopsis when space); Play stays visible | ⬜ |
| 2 | I103-A02 | Focusing an episode shows a thumb border (same language as seasons) | ⬜ |
| 3 | I103-A03 | Multi-season anime: D-pad ↓ from episodes lands on Related (no jump/skip) | ⬜ |
| 4 | I103-A04 | Focusing a trailer card draws a border and does not scale | ⬜ |

---

## Summary

On Android TV, anime details could hide title/synopsis when the episode rail left a tight meta budget (especially 720p landscape — wide but short). Episode cards only bordered when **selected**, not focused. Multi-season titles registered episodes and Related at the same TV `sortOrder`, so D-pad vertical moves jumped. Trailer cards used the default focus scale instead of a flat focus border.

**Root causes:** hero height floor ignored short wide viewports; budget zeroed title while keeping overview; episode border selection-only; anime meta `rowOrder` started at `1` regardless of season row; trailers used default `shellFocusableTap` scale.
