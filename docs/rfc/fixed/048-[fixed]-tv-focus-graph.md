# RFC-048: TV focus graph + screen recipes

**Status:** fixed  
**Depends on:** RFC-028 (adaptive shell + `ShellTvFocusCoordinator`)  
**Area:** `apps/forja/lib/shared/tv/`, Home / hub / Search / Live Matches / IPTV / player overlay recipes  
**Version:** v1.x TV host DX

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6/6** historical · **1 / 1** spatial component · **4 / 4** spatial acceptance |
| **Current slice** | Spatial D-pad default shipped (R48-C07 / R48-A19–A22) — device smoke on issue 135 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R48-C01 | `TvFocusGraph` — tab-scoped facade over `ShellTvFocusCoordinator` rows/memory | ✅ |
| 2 | R48-C02 | `TvCatalogRow` — owns register/unregister + injects tab/row meta | ✅ |
| 3 | R48-C03 | `TvChipStrip` — chip strip edges + chip↔results helpers | ✅ |
| 4 | R48-C04 | `TvHeroActions` — tab defaults / hero reveal bind | ✅ |
| 5 | R48-C05 | `TvGrid` — multi-column results grid (`ShellTvZone.grid` + `moveInGrid`) | ✅ |
| 6 | R48-C06 | `TvOverlayScope` — player menus / sources / dialogs linear D-pad host | ✅ |
| 7 | R48-C07 | Spatial D-pad default — `TvOverlayScope` / settings / chrome use focused-node `focusInDirection`; `ShellTvLinearFocusScope` opt-in only | ✅ |

---

## Acceptance (Home slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R48-A01 | Home wrapped in `TvFocusGraph(tabId: home)`; sections use recipes (no raw row register in Home widgets) | ✅ |
| 2 | R48-A02 | Mood chips use `TvChipStrip`; results UP → chips; left at index 0 → nav | ✅ |
| 3 | R48-A03 | Stremio catalogs use unique `sortOrder`; Show All is inside the row focus graph | ✅ |
| 4 | R48-A04 | Hero uses `TvHeroActions.bind` for tab defaults (Play / gallery anchors unchanged) | ✅ |
| 5 | R48-A05 | Migrated Home surfaces have no raw `LogicalKeyboardKey.arrow*` in section widgets | ✅ |
| 6 | R48-A06 | Unit/widget tests for graph register lifecycle, chip→results, left→nav | ✅ |

---

## Acceptance (hub / Search / overlay)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 7 | R48-A07 | Anime / Asian Drama `HubCatalogSection` + CW + anime mood on `TvCatalogRow` / `TvChipStrip` | ✅ |
| 8 | R48-A08 | `TvGrid` recipe for Search results (+ helpers `TvCatalogRow`, `TvFocusGraph`) | ✅ |
| 9 | R48-A09 | `TvOverlayScope` for player menus / sources / subtitle settings / handoff picker | ✅ |

---

## Acceptance (Live Matches / IPTV)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R48-A10 | Live Matches wrapped in `TvFocusGraph`; sport/CDN chips `TvChipStrip`; card grids `TvGrid`; sheets/timeline `TvCatalogRow`; `TvHeroActions.bind` | ✅ |
| 11 | R48-A11 | IPTV tab `TvFocusGraph` + `TvHeroActions`; browser categories/streams via `iptvCatalogRow`; EPG channels `TvCatalogRow` | ✅ |

---

## Acceptance (lists / settings / details / episodes)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 12 | R48-A12 | My List `TvFocusGraph` + `TvGrid` for posters | ✅ |
| 13 | R48-A13 | Settings hub categories `TvCatalogRow` + `TvHeroActions`; provider priority on recipes; detail panes keep `ShellTvLinearFocusScope` | ✅ |
| 14 | R48-A14 | Hub search (`HubSearchPage`) + shared details rows (cast / trailers / play / torrent actions / season picker / home top bar) on recipes; `MediaDetailsTvScope` uses `TvFocusGraph` + `TvHeroActions` | ✅ |
| 15 | R48-A15 | Player episode panel list registers via `TvCatalogRow` (vertical); no dispose-time raw unregister | ✅ |

---

## Acceptance (embed / profile)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 16 | R48-A16 | Live Matches embed player chrome on `TvFocusGraph` + `TvCatalogRow` (no `iptvSyncRow` / dispose unregister) | ✅ |
| 17 | R48-A17 | Profile chooser uses `TvOverlayScope` (linear D-pad host) | ✅ |

---

## Acceptance (IPTV catalog chrome)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 18 | R48-A18 | IPTV portals / sections / channels / episodes / M3U / portal panel+form / player top+controls / catalog sections+tools use `iptvCatalogRow`; only search-chrome + section-reload keep `iptvSyncRow` | ✅ |

---

## Acceptance (spatial D-pad default)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 19 | R48-A19 | `TvOverlayScope` defaults to spatial (no `ShellTvLinearFocusScope`); optional `linear: true` opt-in | ✅ |
| 20 | R48-A20 | Settings detail / compact / category page: `FocusScope` + `ShellTvContainDpad` trap without linear next/prev arrows | ✅ |
| 21 | R48-A21 | `FocusableControl` / `ForjaInteractive` / `ForjaButton`: arrows prefer `focusInDirection` outside opt-in linear scope | ✅ |
| 22 | R48-A22 | Widget test: 2×2 under spatial `TvOverlayScope` — ↓ from top-left → bottom-left | ✅ |

---

## Summary

Flutter has no TV focus framework. RFC-028 shipped `ShellTvFocusCoordinator` as a **service**. This RFC adds a **declarative focus-graph kit** on top:

```
Screen / overlay
  └── TvFocusGraph (tab) | TvOverlayScope (menus)
        └── Recipes (TvCatalogRow | TvChipStrip | TvHeroActions | TvGrid)
              └── FocusableControl / shellFocusableTap
```

**Hard rule (migrated surfaces):** feature section widgets do not handle `LogicalKeyboardKey.arrow*` — only recipes + coordinator do.

Nav rail, Back ladder, and `PlayerTvKeyScope` (chrome-hidden seek) stay outside this RFC.

### Related

- [RFC-028](../028-[draft]-adaptive-shell-profiles.md) — adaptive shell + coordinator
- [Issue 025](../../issues/025-[open]-android-tv-leanback-smoke-unverified.md) — leanback smoke (unchanged gate)
