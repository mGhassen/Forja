# RFC-111: Foundation widgets — delete dead / honesty vs PackPaintTree

**Status:** fixed  
**Depends on:** RFC-106, RFC-109  
**Area:** `packages/forja_foundation/lib/widgets/`, `protocol/layout_map.dart`, host kit painter

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** components · **6 / 6** acceptance |
| **Current slice** | Delete-dead shipped — PackPaintTree wire out of scope |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R111-C01 | Delete true aliases/forks (Tabs, Chip, ActionChip, MoviePoster, ResolvePanel, list_status_button, SectionTitle) | ✅ |
| 2 | R111-C02 | Delete unwired catalog layout + menu/tabs cascade + heroes + atmosphere + filter sheet | ✅ |
| 3 | R111-C03 | Delete HubTopBar/TopBar* + foundation guide clones; fix host re-exports | ✅ |
| 4 | R111-C04 | Honest layout_map + barrels + MIGRATION + tests | ✅ |

---

## Acceptance (delete-dead slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R111-A01 | Dead widget files removed; no leftover package imports of deleted symbols | ✅ |
| 2 | R111-A02 | `layout_map` no longer names deleted widget classes | ✅ |
| 3 | R111-A03 | `widgets.dart` / `components.dart` barrels match kept files | ✅ |
| 4 | R111-A04 | Host HubTopBar / ResolvePanel re-exports removed | ✅ |
| 5 | R111-A05 | Foundation + targeted app analyze clean on touched paths | ✅ |
| 6 | R111-A06 | Pack `LayoutTypes` constants remain (opaque); wire slice deferred | ✅ |

---

## Summary

`PackPaintTree` only mounts stack / row|rail|ranked / posterCard / eventCard plus verified live host widgets. Many foundation composers were never wired (or were forked in host). This RFC deletes that dead set and makes `layout_map` honest. Wiring pack `hero` / `mood` / `continue` / `menu` / `tabs` is a later slice.

## Goals

- One source of truth: live paint only under `widgets/`
- No duplicate aliases (`Tabs`, `ResolvePanel`, `ForjaActionChip`, …)
- No layout_map claims for deleted classes

## Out of scope

- Mounting unwired pack layout types in PackPaintTree
- Host player chrome (`PlayerTopBar*`)
- Merging DetailsHero with deleted cinematic hero
