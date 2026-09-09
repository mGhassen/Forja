# 265 — Android TV Live Sports ↓ from shelf / Portals does not restore match

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Live Sports · Android TV · `ShellTvFocusCoordinator` · kit list / top bar

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I265-T01 | `focusRowItemRemembered` + row scroll-into-view registry for lazy schedule restore | ✅ |
| 2 | I265-T02 | Chip-strip / vertical ↓ and `kitFocusEdge(last: true)` use remembered restore | ✅ |
| 3 | I265-T03 | Top bar `focusDown` uses `last: true`; Live Sports packs target `schedule` | ✅ |
| 4 | I265-T04 | `KitListWidget` registers scroll helper; dense ↑ prefers kind bar | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I265-A01 | Manual ATV: match mid-list → ↑ sport shelf → ↓ lands on same match (list scrolls) | ⬜ |
| 2 | I265-A02 | Manual ATV: match → ↑ Portals → ↓ lands on same match | ⬜ |

---

## Summary

**Symptom:** On Android TV Live Sports, ↑ from a match to the sport shelf (or to **Portals**) then ↓ left focus stuck or failed to return to that match.

**Root cause:** Schedule is a lazy `ListView`/`Grid`. Off-screen tiles unregister. ↓ used `focusRowItem` without scrolling; the key was still consumed via `onDownEdge`. Top bar `focusDown: 'kind'` also skipped restoring the schedule index.

**Fix:** Scroll the schedule to the remembered index, retry focus across frames, and point chrome ↓ at `schedule` with last-index restore (hub pack layout + host `kitFocusEdge`).
