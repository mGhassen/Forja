# 127 — Android TV Settings detail D-pad escapes to category rail

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I127-T01 | Detail pane: remove ← edge exit to category rail; Back returns focus to selected category | ✅ |
| 2 | I127-T02 | Block auto Left→nav inside `ShellTvLinearFocusScope` (profile/lists/debrid `navLeftAlways`, scaffold `listIndex: 0`) | ✅ |
| 3 | I127-T03 | `ForjaButton` / text fields / remove rows / scoring chips stay in linear detail traversal | ✅ |
| 4 | I127-T04 | Feature docs + changelog: OK/→ enter detail; D-pad stays right; Back exits left | ✅ |
| 5 | I127-T05 | OK/→ from category rail lands focus on first detail control (`SettingsDetailEnter` + scaffold land) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I127-A01 | Android TV Settings: OK/→ from a category enters the right pane; ↑/↓/←/→ move only among detail controls | ⬜ |
| 2 | I127-A02 | Back from detail returns to the selected category; further Back steps to first category then nav rail | ⬜ |

---

## Summary

On **Android TV**, Settings uses a left category rail and a right detail pane. **OK** / **→** should enter the detail; D-pad should stay in the right pane; only **Back** should return to the left rail. Several detail controls wired `navLeftAlways` / `listIndex: 0` / linear `onBackwardEdge`, so **←** jumped to the category rail or shell nav mid-pane.

**Symptom fix:** Trap D-pad inside the detail `FocusScope` + linear scope; Back ladder unchanged (`detail → selected category → first category → nav`).

**Root fix:** Same — focus ownership for settings rows/buttons (no geometry leak via raw `InkWell` / `IconButton`).

**Related:** [RFC-033](../rfc/033-[open]-settings-ux-redesign.md) · [settings overview](../features/settings/overview.md) · backlog [B101-S161](../backlog/1.0.1-[open].md)
