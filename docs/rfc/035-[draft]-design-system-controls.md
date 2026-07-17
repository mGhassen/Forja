# RFC-035: Design-system controls consolidation

**Status:** draft  
**Depends on:** [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md) (tokens / buttons), [issue 078](../issues/fixed/078-[fixed]-switches-not-in-design-system.md) (`ForjaSwitch` shipped)  
**Area:** `apps/forja/lib/shared/design/`, call sites across settings / player / hubs

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** components · **0 / 6** acceptance |
| **Current slice** | Spec only — not scheduled |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R35-C01 | `ForjaSlider` (+ theme) — seek / volume / settings sliders share tokens | ⬜ |
| 2 | R35-C02 | `ForjaSwitchListTile` (or documented theme-only list-tile pattern) | ⬜ |
| 3 | R35-C03 | Design-system rule + barrel: one import path for controls | ⬜ |
| 4 | R35-C04 | Audit + migrate remaining ad-hoc Material control colors | ⬜ |

---

## Acceptance (controls consolidation)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R35-A01 | Changing `ForjaSwitch` / `ForjaSlider` tokens updates all in-scope toggles and sliders | ⬜ |
| 2 | R35-A02 | No new raw `Switch(` / ad-hoc `Slider` color overrides outside `shared/design/` | ⬜ |
| 3 | R35-A03 | Settings, player chrome, and hub screens use shared controls (or inherit theme) | ⬜ |
| 4 | R35-A04 | Cursor rule `forja-design-system.mdc` lists each control + when to use it | ⬜ |
| 5 | R35-A05 | Feature docs unchanged unless user-visible look changes | ⬜ |
| 6 | R35-A06 | `flutter analyze` clean on touched design + migrated call sites | ⬜ |

---

## Summary

RFC-025 shipped shell tokens and buttons. Issue 078 added `ForjaSwitch` so toggles share one style. Most other interactive chrome (sliders, list tiles, one-off Material color knobs) is still local.

This RFC finishes the **controls** slice of the design system: extract remaining primitives into `shared/design/`, wire theme defaults, migrate call sites, and keep the rule file as the contract so the next redesign is one place.

## Goals

1. One source of truth for toggle / slider / list-tile control look.
2. Theme inheritance for Material wrappers that cannot take a custom child easily.
3. Stop ad-hoc `activeTrackColor` / `thumbColor` copies in feature screens.

## Non-goals

- New visual language (colors stay `ForjaShellColors`)
- Rewriting settings hub layout (RFC-033)
- Public web / React design system
- Full god-file splits (RFC-019)

## Precursor (already shipped)

| Item | Status |
|------|--------|
| `ForjaSwitch` + `forjaSwitchThemeData` | ✅ issue 078 |
| Settings / player / audiobook switch call sites | ✅ issue 078 |

## Related

- [RFC-025](fixed/025-[fixed]-flat-cinematic-shell.md) — flat shell + buttons
- [RFC-033](033-[open]-settings-ux-redesign.md) — settings hub (consumes design tokens)
- [issue 078](../issues/fixed/078-[fixed]-switches-not-in-design-system.md) — switch extraction
- `.cursor/rules/forja-design-system.mdc`
