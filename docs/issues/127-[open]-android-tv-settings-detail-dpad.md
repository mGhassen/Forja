# 127 — Android TV Settings detail D-pad escapes to category rail

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings · D-pad focus

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 2** acceptance (legacy ladder) · **1 / 1** acceptance (corrected Back) · **0 / 2** acceptance (Addons ↑ + ← exit) · **0 / 2** acceptance (spatial pages) |

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
| 8 | I127-T08 | Drop settings `ShellTvLinearFocusScope` (spatial pages); ↑ never calls pageBack; packs chip/install rows clear of `settings-categories` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I127-A01 | Android TV Settings: OK/→ from a category enters the right pane; ↑/↓/←/→ move only among detail controls | ⬜ |
| 2 | I127-A02 | Back from detail returns to the selected category; further Back steps to first category then nav rail | ⬜ |
| 3 | I127-A03 | Back: nested drill → detail list → selected category → nav (no hop to first category); Addons→Stremio restores list focus | ✅ |
| 4 | I127-A04 | Addons: ↑ from IPTV lands on Playback with green focus chrome (not category rail / invisible) | ⬜ |
| 5 | I127-A05 | Detail: ↑/↓/→ stay in the right page; ← or Back returns to the selected category (or closes nested drill first) | ⬜ |
| 6 | I127-A06 | Settings pages are spatial (→ ≠ next-in-list); ↑ on first control stays in-page (Packs install + Playback) | ⬜ |
| 7 | I127-A07 | Forja Packs chip strip / install checklist ↑ never lands on the category rail | ⬜ |

---

## Summary

On **Android TV**, Settings uses a left category rail and a right category page. **OK** / **→** should enter the page; **↑/↓/→** stay in that page (spatial neighbors — not a 1D next/prev line); **←** or **Back** returns to the left rail (nested drill first).

**Regression:** wrapping every category page in `ShellTvLinearFocusScope` remapped **→** = next and made **↑** on the first control call `onBackwardEdge` → category rail. Pack chip strips also used `sortOrder: 0` (same as `settings-categories`), so ↑ jumped left.

**Fix (T08):** spatial D-pad inside each page (`ContainDpad` + `FocusScope`); **↑** never pageBack; packs rows at `sortOrder` 100+ with ↑ traps.

**Related:** [RFC-033](../rfc/033-[open]-settings-ux-redesign.md) · [settings overview](../features/settings/overview.md)
