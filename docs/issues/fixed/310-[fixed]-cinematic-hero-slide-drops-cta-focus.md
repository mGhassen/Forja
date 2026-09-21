# 310 — Cinematic hero slide drops CTA focus

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** TV · Desktop keyboard · hub cinematic hero carousel

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I310-T01 | `CinematicHero`: CrossfadeSwap title/meta/overview only — keep action row outside remount | ✅ |
| 2 | I310-T02 | Widget test: shared CTA FocusNode stays focused across `stepFilm` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I310-A01 | Home Spotlight: focus on View details (or Follow) survives auto/manual backdrop slide | ⬜ |
| 2 | I310-A02 | Same on Anime / Asian Drama hub heroes | ⬜ |

---

## Summary

Hero text used `CrossfadeSwap` + `ValueKey(slide.id)` around the **whole** column (including host CTAs). Every carousel advance remounted the action row; shared FocusNodes detached and TV/desktop focus evaporated.

Related earlier fix: [200](200-[fixed]-android-tv-home-hero-focus-disposed.md) (inactive PageView slides owning FocusNodes). This regression is the overlay text crossfade remounting CTAs.

**Root fix:** crossfade chrome only; action row stays a stable sibling and updates in place.
