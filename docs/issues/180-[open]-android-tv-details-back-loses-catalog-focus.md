# 180 — Android TV: Back from details lands on Home top menu

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Home · details overlay · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I180-T01 | Snapshot tab memory in `maybePopShellOverlay` before chrome remounts | ✅ |
| 2 | I180-T02 | After overlay pop, restore last catalog card (not top bar / hero Play) | ✅ |
| 3 | I180-T03 | Coordinator test: top-bar remount pollutes memory; restore still lands on card | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I180-A01 | Android TV Home: focus a mid-row card → details → Back: scroll stays; D-pad is on that card, not Search / Films | ⬜ |

---

## Summary

Back from media details kept Home scroll on the last card, but D-pad jumped to the Home top menu (Search / Films / TV Shows / Categories).

**Root cause:** overlay pop never restored tab memory. Home’s top bar unmounts while details is open; on pop it remounts and Flutter lands focus on the first chrome control. `notifyFocused` then overwrites catalog-row memory with `ShellTvZone.topBar`. Scroll is keep-alive, so the viewport stayed put.

**Symptom fix = root fix** in `maybePopShellOverlay` + `shell_tv_coordinator.dart`.
