# 127 — Android TV Settings detail D-pad escapes to category rail

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 2** acceptance (legacy ladder) · **1 / 1** acceptance (corrected Back) · **0 / 2** acceptance (Addons ↑ + ← exit) |

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
| 6 | I127-T06 | Addons list: isolate `TvKitRow` from `settings-categories` (`sortOrder` 100+, explicit ↑/↓) so ↑ from IPTV lands on Playback | ✅ |
| 7 | I127-T07 | Detail ← exit: first linear control + row column-0 call `pageBack` (same ladder as Back) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I127-A01 | Android TV Settings: OK/→ from a category enters the right pane; ↑/↓/←/→ move only among detail controls | ⬜ |
| 2 | I127-A02 | Back from detail returns to the selected category; further Back steps to first category then nav rail | ⬜ |
| 3 | I127-A03 | Back: nested drill → detail list → selected category → nav (no hop to first category); Addons→Stremio restores list focus | ✅ |
| 4 | I127-A04 | Addons: ↑ from IPTV lands on Playback with green focus chrome (not category rail / invisible) | ⬜ |
| 5 | I127-A05 | Detail: ↑/↓/→ stay in the right page; ← or Back returns to the selected category (or closes nested drill first) | ⬜ |

---

## Summary

On **Android TV**, Settings uses a left category rail and a right detail pane. **OK** / **→** should enter the detail; **↑/↓/→** stay in the right page; **←** or **Back** returns to the left rail (nested drill first).

**Regression (Addons):** Addon rows registered `TvKitRow` with `sortOrder: index` (Playback = 0), colliding with `settings-categories` (also 0). ↑ from IPTV called `moveVerticalInTab` and focused the category rail — Addons looked focused while Playback lost chrome (“invisible”).

**Symptom fix:** Trap D-pad inside the detail `FocusScope` + contain; Back / ← ladder is nested drill → detail → selected category → nav (no Profile hop).

**Root fix (T06/T07):** Addons ↑/↓ only walk sibling addon rows (`sortOrder` 100+, `onFocusUp`/`onFocusDown`); ← at column 0 / first linear control runs `pageBack`.

**Related:** [RFC-033](../rfc/033-[open]-settings-ux-redesign.md) · [settings overview](../features/settings/overview.md)
