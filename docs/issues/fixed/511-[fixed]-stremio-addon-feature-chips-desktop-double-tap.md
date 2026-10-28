# 511 — Stremio Sources / Live Sports chips look dead on desktop

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Settings → Addons → Stremio · desktop hybrid · `_AddonFeatureChip`  
**Reported:** 2026-10-28 (desktop click on Sources / Live Sports chips)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** fix · **0 / 1** acceptance |
| **Current slice** | Root fix landed — desktop click re-test |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Settings → Addons → Stremio: clicking **Sources** / **Live Sports** under an installed addon does nothing on desktop. Chips look tappable but selection never changes.

## Root cause

`_AddonFeatureChip` gated the TV wrap on `useFocusableMoodChips`. Desktop hybrid sets that flag, so chips wrapped in `shellFocusableTap` (`FocusableControl`) **and** kept an inner `InkWell(onTap:)`.

`FocusableControl` fires on mouse **pointerDown**; nested `InkWell` fires again on tap **up**. Two toggles of the same feature cancel each other — looks dead. Same anti-pattern that `ForjaShellChip` already avoids (face only under FocusableControl).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I511-T01 | TV/desktop focusable path: paint face only under `shellFocusableTap`; InkWell only on non-focusable path (match `ForjaShellChip`) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I511-A01 | Desktop: click Sources or Live Sports when both are on → one deselects; click the off chip → selects again; sole remaining chip stays on | ⬜ |

## Links

- [RFC-050](../../rfc/050-[open]-stremio-addon-feature-targets.md)
- [stremio-addons](../../features/sources/stremio-addons.md)
