# RFC-033: Settings category-hub UX redesign

**Status:** open  
**Depends on:** RFC-023 (shell), RFC-025 (flat cinematic shell)  
**Area:** `apps/forja/lib/features/settings/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** components · **10 / 10** acceptance (category hub) · **6 / 6** acceptance (profile visibility) · **3 / 3** acceptance (TV detail focus) · **1 / 1** acceptance (resume selection) |
| **Current slice** | Resume: keep Settings category across background sync |

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
| 6 | R33-C06 | WebStreamr as hub category (`SettingsWebstreamrSection`) | ✅ |
| 7 | R33-C07 | Lists as hub category (`ListsScreen(embedded: true)`) | ✅ |
| 8 | R33-C08 | `SettingsVisibility` gates hub tiles + category rows from play sources / IPTV nav | ✅ |

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
| 9 | R33-A09 | WebStreamr openable as **Settings → WebStreamr** (not nested push only) | ✅ |
| 10 | R33-A10 | Lists openable as **Settings → Lists** (not nested push only) | ✅ |

---

## Acceptance (profile visibility)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R33-A11 | Hide **Sources** + **Debrid** when Direct torrent and Stremio are both off | ✅ |
| 2 | R33-A12 | Hide **WebStreamr** (and Playback server reliability) when Webstreaming is off | ✅ |
| 3 | R33-A13 | Sources body shows only torrent / Stremio / Nuvio / Jackett blocks that match enabled play sources (+ platform torrent cap) | ✅ |
| 4 | R33-A14 | Hide IPTV EPG, portals CSV, and IPTV portal cache clear when IPTV tab is hidden | ✅ |
| 5 | R33-A15 | Hub list refreshes live when play-source or Navigation toggles change; selection falls back if tile disappears | ✅ |
| 6 | R33-A16 | No VOD tab (Home/Search/Anime/Asian Drama/My List) → hide Sources, WebStreamr, Debrid, Connected services, Lists, and Playback play-source / scoring / episode extras | ✅ |

---

## Acceptance (TV detail focus)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R33-A17 | Split TV: OK/→ from category enters detail and lands on the first right-pane control; ↑/↓/←/→ stay in the right pane (no ← exit to rail) | ✅ |
| 2 | R33-A18 | Back from detail → selected category → first category → nav rail | ✅ |
| 3 | R33-A19 | TV select rows: OK opens D-pad option list (selected highlighted); chrome unchanged | ✅ |

---

## Acceptance (resume selection)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R33-A20 | Background → resume keeps the open Settings category; desktop hybrid must not focus→select Profile on rebuild | ✅ |

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
