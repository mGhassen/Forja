# 314 — Details episodes range pad, chips view, D-pad grid

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** media details · Home pack settings · Android TV D-pad  
**Reported:** 2026-09-22

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I314-T01 | Episodes range control (1–50 / …) has content end padding | ✅ |
| 2 | I314-T02 | When range exists, D-pad lands on it before seasons (then episodes) | ✅ |
| 3 | I314-T03 | Home hub pack settings: Episode list Cards vs Number chips | ✅ |
| 4 | I314-T04 | Number chips paint as a wrap grid with 2D D-pad (`ShellPaintScope.tvGrid`) | ✅ |
| 5 | I314-T05 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I314-A01 | Long series details: range pill is not flush to the right edge | ⬜ |
| 2 | I314-A02 | Android TV: ↓ from Play reaches range (when shown) before season posters | ⬜ |
| 3 | I314-A03 | Forja Packs → expand Home → Episode list → Number chips switches details to a number grid | ⬜ |
| 4 | I314-A04 | Chips mode: D-pad ←/→/↑/↓ moves across the grid (not only one horizontal line) | ⬜ |

---

## Summary

Series details **Episodes** header range control sits too close to the screen edge and is outside the TV focus graph (seasons register first). Users want a Home pack setting to show episodes as **Cards** (stills) or **Number chips** in a wrapping grid with real 2D D-pad.

**Root fix:** pad the title row; register `episode-range` before seasons; Home pack `settings.select` `episodeView` (Forja Packs expand — no host Addons row); chips via foundation grid + host `TvGrid` wrap.
