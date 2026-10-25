# 491 — Android TV Simkl sync mode select won’t open on D-pad

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Connected services → Simkl · D-pad  
**Reported:** 2026-10-25 (ATV: OK on “How should lists sync?” does nothing)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 1/1** · A **0/1** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On **Android TV**, Settings → Connected services → Simkl: focus lands on **How should lists sync?**, but **OK** does not open the option list. Sync mode cannot be changed with the remote.

## Root cause

`SettingsSimklPanel` forced `SettingsSelectRow(inlineDropdown: true)`, so TV used Material `DropdownButton` instead of the leanback path (`showSettingsSelectDialog` on activate). Row `onTap` / activate key handlers stay null when `useDropdown` is true.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I491-T01 | Drop `inlineDropdown: true` on Simkl sync `SettingsSelectRow` so TV uses the focused select dialog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I491-A01 | Android TV: OK on Simkl “How should lists sync?” opens Keep local / Use Simkl / Merge / No sync; pick changes the saved mode | ⬜ |

## Links

- Changelog note (TV select dialog pattern): `docs/changelog/done/1.3.267-[released].md`
