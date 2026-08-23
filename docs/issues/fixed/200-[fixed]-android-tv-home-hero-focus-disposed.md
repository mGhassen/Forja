# 200 — Android TV Home hero loses focus (FocusNode disposed)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Home / hub cinematic hero · `ForjaInteractive` · `ShellTvFocus`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I200-T01 | Inactive PageView hero slides: no `onTap` / TV meta / shared `hero-play` (no owned `forja-interactive` FocusNode) | ✅ |
| 2 | I200-T02 | `ForjaInteractive`: only own a FocusNode when focusable; defer dispose after unfocus | ✅ |
| 3 | I200-T03 | `HomeCinematicHero`: defer dispose of `hero-play` / `hero-gallery` after unfocus | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I200-A01 | ATV Home: D-pad gallery L/R + Play ↔ nav ↔ menu without `FocusNode was used after being disposed` or lost focus | ⬜ |
| 2 | I200-A02 | Same on Anime / Asian Drama hub heroes (shared `HomeCinematicHero`) | ⬜ |

---

## Summary

Carousel slides gated `focusNode: isActive ? hero-play : null` while keeping `onTap`, so inactive slides owned ephemeral `forja-interactive` nodes. Stepping the hero disposed those nodes while FocusManager still notified → focus evaporated to nav / nowhere.

**Root fix:** inactive slides are visual-only; shared hero FocusNodes dispose only after unfocus microtask.
