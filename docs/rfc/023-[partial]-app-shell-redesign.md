# RFC-023: App shell & navigation redesign

**Status:** partial  
**Version:** v0.8.0  
**Target version:** [0.8.0](../backlog/0.8.0-[open].md)  
**Depends on:** RFC-001 (monorepo), RFC-011 (v1.0 MVP shell shipped)  
**Area:** `apps/forja/lib/shell/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **6 / 9** acceptance (0.8.0 slice) |
| **Current slice** | 0.8.0 — all nav tabs body-only; slice 2 = IPTV/Music polish |
| **Backlog** | [0.8.0](../backlog/0.8.0-[open].md) |

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
- IPTV immersive mode (hide global nav) — slice 2
- Music double-sidebar resolution — slice 2
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

### Slice 1 — v0.8.0 (this ship)

| Component | Action | Status |
|-----------|--------|--------|
| `NavDestination` | Typed registry; remove settings `_navMeta` duplicate | Shipped |
| `ShellScaffold` / `ShellNavRail` / `ShellBottomNav` / `ShellBody` | Extract from `MainScreen` | Shipped |
| `shell_tokens.dart` | Wire spacing into nav chrome | Shipped |
| Home + Settings + Search | Body-only; Search uses `ShellSearchBar` in shell | Shipped |
| All other nav tabs | Body-only (no nested shell `Scaffold`) | Shipped *(0.8.0)* |

### Slice 2 — v0.8.x patches

- IPTV immersive mode rules (hide global nav)
- Music internal sidebar vs global shell

### Slice 3 — follow-on (when scheduled)

- RFC-003 player overlay, RFC-004/005 providers/casting — own backlog entries

## Contracts (must not break)

| Contract | Location |
|----------|----------|
| `ShellBus.requestTab` | `shell_bus.dart` |
| `ShellBus.stremioSearchNotifier` | `shell_bus.dart` |
| `ShellBus.splashDismissed` | `shell_bus.dart` |
| `SettingsService.allNavIds` + `navbarChangeNotifier` | `packages/rust` |
| Platform torrent nav filtering | `main_screen.dart` |
| Lazy `_tabCache` + `_mountedTabIds` | `main_screen.dart` |
| `DesktopWindowChrome.wrapShell()` | `bootstrap.dart` path |
| `AppRouter` push helpers | `app_router.dart` |

## Acceptance (0.8.0)

- [x] `NavDestination` typed; settings uses shared registry (no `_navMeta`)
- [x] `ShellScaffold` + extracted nav widgets; `MainScreen` slimmed
- [x] Home + Settings + Search body-only (no nested `Scaffold`); Search bar in shell
- [x] All nav tab roots body-only
- [x] Shell tokens wired into nav chrome
- [ ] Desktop: rail, logo inset, tab switch, single background on Home/Settings
- [ ] Mobile portrait: bottom nav scroll, safe area, tab switch
- [ ] Settings → Navigation Bar: reorder/toggle persists
- [ ] `ShellBus.requestTab('search')` still switches tabs
- [x] `flutter analyze` clean on touched files

## Related

RFC-001, RFC-011, RFC-016 (lazy tabs — partially shipped), RFC-018 (splash), RFC-019 (god files), [0.8.0 backlog](../backlog/0.8.0-[open].md)
