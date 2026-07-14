# RFC-033: Settings category-hub UX redesign

**Status:** open  
**Depends on:** RFC-023 (shell), RFC-025 (flat cinematic shell)  
**Area:** `apps/forja/lib/features/settings/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **8 / 8** acceptance |
| **Current slice** | Category hub shipped — sidebar wide / list→detail narrow+TV |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R33-C01 | `SettingsTokens` + shared row/tile/group primitives | ✅ |
| 2 | R33-C02 | `SettingsHubScaffold` (sidebar | list→push) + category catalog | ✅ |
| 3 | R33-C03 | Category pages (playback, sources, debrid, accounts, data, navigation, about) | ✅ |
| 4 | R33-C04 | Retire accordion; restyle to `ForjaShellColors` | ✅ |
| 5 | R33-C05 | TV / D-pad focus on category tiles and rows | ✅ |

---

## Acceptance (category hub)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R33-A01 | Wide non-TV: left category rail + right detail pane | ✅ |
| 2 | R33-A02 | Mobile / compact / TV: category list → push detail page | ✅ |
| 3 | R33-A03 | Only selected category body mounts (lazy) | ✅ |
| 4 | R33-A04 | All former accordion settings reachable under new categories | ✅ |
| 5 | R33-A05 | Platform gates unchanged (torrent UI, Android engine) | ✅ |
| 6 | R33-A06 | Category tiles + settings rows D-pad focusable on TV | ✅ |
| 7 | R33-A07 | Feature docs match hub paths | ✅ |
| 8 | R33-A08 | `flutter analyze` clean on touched settings/design files | ✅ |

---

## Summary

Replace the single long accordion Settings tab with a **category hub**: desktop/wide uses a persistent sidebar + detail pane; mobile and TV use a category list that pushes detail pages. Shared settings primitives and shell colors replace ad-hoc Material / purple styling. Prefs and `SettingsService` keys are unchanged.

## Goals

1. Find any setting in one or two taps without scrolling a thousand-line accordion.
2. Match flat cinematic shell language (`ForjaShellColors`, design buttons).
3. Lazy-load heavy category bodies (providers, scoring).
4. Keep TV D-pad usable on category list and detail rows.

## Non-goals

- Appearance / theme picker
- Settings sync (RFC-006)
- Changing persisted keys or sync payloads

## Related

- [RFC-019](019-[draft]-god-file-decomposition.md) — settings file map (remainder)
- [RFC-023](fixed/023-[fixed]-app-shell-redesign.md) — app shell
- [docs/features/settings/](../features/settings/)
