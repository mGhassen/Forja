# RFC-023: App shell & navigation redesign

**Status:** partial  
**Version:** v0.8.0  
**Target version:** [0.8.0](../backlog/0.8.0-[open].md)  
**Depends on:** RFC-001 (monorepo), RFC-011 (v1.0 MVP shell shipped)  
**Area:** `apps/forja/lib/shell/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **9 / 14** acceptance (0.8.0) |
| **Current slice** | Device smoke → close 0.8.0 |
| **Backlog** | [0.8.0](../backlog/0.8.0-[open].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R23-C01 | `NavDestination` typed registry; remove settings `_navMeta` duplicate | ✅ |
| 2 | R23-C02 | `ShellScaffold` / `ShellNavRail` / `ShellBottomNav` / `ShellBody` extracted from `MainScreen` | ✅ |
| 3 | R23-C03 | `shell_tokens.dart` wired into nav chrome | ✅ |
| 4 | R23-C04 | Home + Settings + Search body-only; Search uses `ShellSearchBar` in shell | ✅ |
| 5 | R23-C05 | All other nav tab roots body-only (no nested shell `Scaffold`) | ✅ |

---

## Acceptance (0.8.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R23-A01 | `NavDestination` typed; settings uses shared registry (no `_navMeta`) | ✅ |
| 2 | R23-A02 | `ShellScaffold` + extracted nav widgets; `MainScreen` slimmed | ✅ |
| 3 | R23-A03 | Home + Settings + Search body-only; Search bar in shell | ✅ |
| 4 | R23-A04 | All nav tab roots body-only | ✅ |
| 5 | R23-A05 | Shell tokens wired into nav chrome | ✅ |
| 6 | R23-A06 | IPTV immersive: global nav hidden past portal list | ✅ |
| 7 | R23-A07 | Music desktop: global rail hidden (internal sidebar only) | ✅ |
| 8 | R23-A08 | Automated shell tests (`shell_scaffold_test`, `shell_bus_test`) | ✅ |
| 9 | R23-A09 | `flutter analyze` clean on touched files | ✅ |
| 10 | R23-A10 | Desktop: rail, logo inset, tab switch, single background *(device smoke)* | ⬜ |
| 11 | R23-A11 | Mobile portrait: bottom nav scroll, safe area, tab switch *(device smoke)* | ⬜ |
| 12 | R23-A12 | Settings → Navigation Bar: reorder/toggle persists *(device smoke)* | ⬜ |
| 13 | R23-A13 | `ShellBus.requestTab('search')` still switches tabs *(device smoke)* | ⬜ |
| 14 | R23-A14 | IPTV deep view + Music desktop — global nav hidden *(device smoke)* | ⬜ |

---

## Summary

Rework the primary app shell so menu, background, and body are owned once — not duplicated across `MainScreen` and every nav tab. Introduce typed nav metadata, extracted shell widgets, and migrate tabs to body-only content incrementally.

## Problem

1. **Monolithic `MainScreen`** — [`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart) owns background glows, `NavigationRail`, custom bottom nav, lazy `IndexedStack`, lifecycle hooks, and update checks in one ~420-line widget.

2. **Duplicated nav metadata** — [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) `navMeta` vs [`settings_screen.dart`](../../apps/forja/lib/features/settings/settings_screen.dart) `_navMeta`. Adding or renaming a tab requires editing multiple files.

3. **Nested scaffolds** — Shell `Scaffold` wraps tab widgets that each return their own `Scaffold`, duplicating backgrounds and fighting safe-area / inset math.

4. **Unwired design stubs** — [`shared/design/`](../../apps/forja/lib/shared/design/) exists but is not consumed by the live shell.

## Goals

- Single shell owns background, nav chrome, and body slot
- Typed `NavDestination` registry — single source for icons, labels, builders
- Body-only tab widgets (no nested `Scaffold`) — migrated incrementally
- Preserve existing contracts: `ShellBus`, navbar settings, lazy tab cache, `DesktopWindowChrome`, `AppRouter`

## Non-goals (0.8.0)

- GoRouter / deep-link routing overhaul
- IPTV immersive mode (hide global nav) — **shipped** (`ShellBus.hideGlobalNav`)
- Music double-sidebar resolution — **shipped** (hide global rail on desktop Music tab)
- Full 19-tab migration — **done in 0.8.0** (all nav tab roots body-only)
- Player overlay (RFC-003) — separate RFC/backlog when scheduled
- Home god-file decomposition (RFC-019)

## Target layout

```
apps/forja/lib/shell/
  main_screen.dart          # coordinator: state, ShellBus, navbar config
  nav_config.dart           # NavDestination registry + navTabBuilders
  shell_scaffold.dart       # bg, Row(menu|body), bottom nav slot
  shell_nav_rail.dart       # desktop / landscape rail
  shell_bottom_nav.dart     # portrait mobile bottom bar
  shell_body.dart           # IndexedStack + lazy tab API
  shell_bus.dart            # unchanged
  app_router.dart           # unchanged in 0.8.0

apps/forja/lib/shared/design/
  src/shell_tokens.dart     # nav width, bottom bar height, insets
  src/shell_tab_header.dart # optional per-tab title row
```

## Slices

### Slice 1 — v0.8.0 code *(shipped)*

R23-C01 through R23-C05 · R23-A01 through R23-A09 — all ✅

### Slice 2 — v0.8.0 device smoke *(open)*

R23-A10 through R23-A14 — all ⬜; blocks `[fixed]` and 0.8.0 close

### Slice 3 — follow-on *(deferred)*

- RFC-003 player overlay, RFC-004/005 providers/casting — own backlog entries

## Contracts (must not break)

| Contract | Location |
|----------|----------|
| `ShellBus.requestTab` | `shell_bus.dart` |
| `ShellBus.stremioSearchNotifier` | `shell_bus.dart` |
| `ShellBus.splashDismissed` | `shell_bus.dart` |
| `SettingsService.allNavIds` + `navbarChangeNotifier` | `packages/rust` |
| Platform torrent nav filtering | `main_screen.dart` |
| `ShellBus.hideGlobalNav` | `shell_bus.dart` |
| Lazy `_tabCache` + `_mountedTabIds` | `main_screen.dart` |
| `DesktopWindowChrome.wrapShell()` | `bootstrap.dart` path |
| `AppRouter` push helpers | `app_router.dart` |

## Related

RFC-001, RFC-011, RFC-016 (lazy tabs — partially shipped), RFC-018 (splash), RFC-019 (god files), [0.8.0 backlog](../backlog/0.8.0-[open].md)
