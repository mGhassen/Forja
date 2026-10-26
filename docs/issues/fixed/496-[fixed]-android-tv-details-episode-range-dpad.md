# 496 — Android TV details episode range (1–50) D-pad won’t open

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · media details · Episodes chrome · D-pad  
**Reported:** 2026-10-26 (ATV: 1–50 range control unreachable / menu dead with remote)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** · A **0/1** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On **Android TV**, series details with more than 50 episodes: the **1 - 50** range control sits in the Episodes chrome row, but opening and picking a range with the remote does nothing useful (Material menu is not leanback-safe). Same control in the player Episodes panel.

## Root cause

`EpisodeRangeSelector` used Material `MenuAnchor` / `MenuItemButton` on TV. Same class of failure as Settings `DropdownButton` ([491](491-[fixed]-android-tv-simkl-sync-select-dpad.md)): overlay menu items do not take D-pad under the shell focus graph. Cast ↑ also fell back to a dead row id `episode-range` after chrome merged into `episode-chrome`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I496-T01 | Leanback: OK on range opens focusable select dialog; desktop keeps MenuAnchor | ✅ |
| 2 | I496-T02 | Details Cast ↑ fallback uses `episode-chrome` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I496-A01 | Android TV long series: OK on 1–50 opens Episode range list; ↓/OK picks 51–100 and filters episodes | ⬜ |

## Links

- [314](../314-[open]-details-episodes-chips-range-dpad.md) — earlier range pad / chrome focus order
- [491](491-[fixed]-android-tv-simkl-sync-select-dpad.md) — TV select-dialog precedent
