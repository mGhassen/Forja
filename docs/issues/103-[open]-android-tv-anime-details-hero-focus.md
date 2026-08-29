# 103 — Android TV anime details: missing hero data + focus chrome

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Anime details · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I103-T01 | Short/720p hero chrome floor + budget: keep title before dropping synopsis | ✅ |
| 2 | I103-T02 | Episode cards show focus border (selected \|\| focused), no scale | ✅ |
| 3 | I103-T03 | Anime details TV row sortOrder after seasons+episodes (no Related collision) | ✅ |
| 4 | I103-T04 | Trailer cards: same catalog focus as posters on desktop + TV (`showFocusBorder`, bleed for 200px thumb) | ✅ |
| 5 | I103-T05 | Details/hub hero budget: keep meta row (type / cert / ★) before dropping synopsis | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I103-A01 | Android TV anime details shows title (+ synopsis when space); Play stays visible | ⬜ |
| 2 | I103-A02 | Focusing an episode shows a thumb border (same language as seasons) | ⬜ |
| 3 | I103-A03 | Multi-season anime: D-pad ↓ from episodes lands on Related (no jump/skip) | ⬜ |
| 4 | I103-A04 | Android TV: focused trailer shows the same white focus ring as poster cards | ⬜ |
| 5 | I103-A05 | Android TV details hero shows type + cert + ★ when data exists (meta before synopsis) | ⬜ |

---

## Summary

On Android TV, anime details could hide title/synopsis when the episode rail left a tight meta budget (especially 720p landscape — wide but short). Episode cards only bordered when **selected**, not focused. Multi-season titles registered episodes and Related at the same TV `sortOrder`, so D-pad vertical moves jumped. Trailer cards used the default focus scale instead of a flat focus border.

**Root causes:** hero height floor ignored short wide viewports; budget zeroed title while keeping overview; episode border selection-only; anime meta `rowOrder` started at `1` regardless of season row; trailers used default `shellFocusableTap` scale.
