# 248 — Android TV player Episodes panel D-pad stuck on Search

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · player · Episodes panel

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I248-T01 | `TvBrowseTextField` overrides TextField selection / directional intents while browsing so ↓/→ are not swallowed | ✅ |
| 2 | I248-T02 | Episode panel search → list / auto-next: `FocusScope.requestFocus`, scroll-into-view retries, spatial fallback | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I248-A01 | Android TV player: open Episodes → ↓ from Search lands on an episode row; → reaches Auto next / Close | ⬜ |
| 2 | I248-A02 | Android TV player: ↑ from first episode returns to Search; OK on Search opens keyboard only (browse focus until OK) | ⬜ |

---

## Summary

On **Android TV**, the player **Episodes** panel left D-pad on **Search**. Logs showed `Arrow Down` / `Arrow Right` with `focus=ep-panel-search` and no focus change. Edge handlers existed (`onSearchDownEdge` → episode list), but `TextField` / `DefaultTextEditingShortcuts` map arrows to selection and `DirectionalFocusAction.forTextField` (ignoreTextFields), which consume keys without moving focus when `FocusNode.onKeyEvent` does not win first. App-root TV directional action also no-ops ←/→.

**Root fix:** parent `Actions` on `TvBrowseTextField` override those intents in browse mode and dispatch the existing `onKeyEvent` edge graph; episode panel focus claim matches Sources (`FocusScope` + retries + spatial ↓ fallback).

## Related

- [161](161-[open]-android-tv-sources-panel-dpad.md) — Sources search ↓ stuck (same TextField class)
- [player](../features/playback/player.md)
