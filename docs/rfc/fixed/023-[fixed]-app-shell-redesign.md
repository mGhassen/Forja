# RFC-023: App shell & navigation redesign

**Status:** fixed  
**Version:** v0.8.0  
**Target version:** [0.8.1](../backlog/done/0.8.1-[done].md) *(core tabs shipped)*  
**Scope:** **desktop only** — rail, immersive chrome, body-only tabs, core tab UX *(shipped — tags `v0.8.0`, `v0.8.1`)*  
**Depends on:** RFC-001 (monorepo), RFC-011 (v1.0 MVP shell shipped)  
**Area:** `apps/forja/lib/shell/`, `apps/forja/lib/shared/design/`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** components · **18 / 18** acceptance (desktop) |
| **Backlog** | [0.8.0](../backlog/done/0.8.0-[done].md) · [0.8.1](../backlog/done/0.8.1-[done].md) |

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

## Acceptance (0.8.0 — desktop)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R23-A01 | `NavDestination` typed; settings uses shared registry (no `_navMeta`) | ✅ |
| 2 | R23-A02 | `ShellScaffold` + extracted nav widgets; `MainScreen` slimmed | ✅ |
| 3 | R23-A03 | Home + Settings + Search body-only; Search bar in shell | ✅ |
| 4 | R23-A04 | All nav tab roots body-only | ✅ |
| 5 | R23-A05 | Shell tokens wired into nav chrome | ✅ |
| 6 | R23-A06 | IPTV immersive: global nav hidden past portal list | ✅ |
| 7 | R23-A07 | Music desktop: global rail hidden (internal sidebar only) | ✅ |
| 8 | R23-A08 | Automated shell tests (`shell_scaffold_test`, `shell_bus_test`, `main_screen_shell_test`) | ✅ |
| 9 | R23-A09 | `flutter analyze` clean on touched files | ✅ |
| 10 | R23-A10 | Desktop: rail, logo inset, tab switch, single background | ✅ |
| 11 | R23-A12 | Settings → Navigation Bar: reorder/toggle persists | ✅ |
| 12 | R23-A13 | `ShellBus.requestTab('search')` still switches tabs | ✅ |
| 13 | R23-A14 | IPTV deep view + Music desktop — global nav hidden | ✅ |

---

## Acceptance (0.8.1 — core tabs, desktop)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 14 | R23-A15 | Home: shell-aligned desktop layout; no duplicate shell background | ✅ |
| 15 | R23-A16 | Search: results body under shell search bar; desktop spacing | ✅ |
| 16 | R23-A17 | My List: `ShellTabHeader`; no floating app-bar chrome | ✅ |
| 17 | R23-A18 | Settings: spacing/typography aligned to `shell_tokens` | ✅ |
| 18 | R23-A19 | Default nav Home · Search · My List · Settings | ✅ |

---

## Summary

Rework the primary app shell so menu, background, and body are owned once — not duplicated across `MainScreen` and every nav tab. Introduce typed nav metadata, extracted shell widgets, and migrate tabs to body-only content incrementally.

## Problem

1. **Monolithic `MainScreen`** — [`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart) owns background glows, `NavigationRail`, custom bottom nav, lazy `IndexedStack`, lifecycle hooks, and update checks in one ~420-line widget.

2. **Duplicated nav metadata** — [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) vs settings duplicate (fixed).

3. **Nested scaffolds** — Shell `Scaffold` wrapped tab widgets that each returned their own `Scaffold` (fixed for all nav tab roots in 0.8.0).

4. **Unwired design stubs** — [`shared/design/`](../../apps/forja/lib/shared/design/) now wired via `shell_tokens`.

## Goals

- Single shell owns background, nav chrome, and body slot
- Typed `NavDestination` registry — single source for icons, labels, builders
- Body-only tab widgets (no nested `Scaffold`)
- Preserve existing contracts: `ShellBus`, navbar settings, lazy tab cache, `DesktopWindowChrome`, `AppRouter`

## Non-goals

- **Mobile shell polish** — out of product scope (desktop-only)
- GoRouter / deep-link routing overhaul
- Player overlay (RFC-003) — separate backlog when scheduled
- Home god-file decomposition (RFC-019)

## Slices

### Slice 1 — v0.8.0 desktop code *(shipped)*

R23-C01–C05 · R23-A01–A10 · R23-A12–A14 — ✅

### Slice 2 — v0.8.1 core tabs *(shipped 0.8.1)*

R23-A15–A19 — ✅

### Slice 3 — follow-on *(deferred)*

- RFC-003 player overlay, RFC-004/005 providers/casting — own backlog entries

## Contracts (must not break)

| Contract | Location |
|----------|----------|
| `ShellBus.requestTab` | `shell_bus.dart` |
| `ShellBus.stremioSearchNotifier` | `shell_bus.dart` |
| `ShellBus.hideGlobalNav` | `shell_bus.dart` |
| `SettingsService.allNavIds` + `navbarChangeNotifier` | `packages/rust` |
| Lazy `_tabCache` + `_mountedTabIds` | `main_screen.dart` |
| `DesktopWindowChrome.wrapShell()` | bootstrap path |
| `AppRouter` push helpers | `app_router.dart` |

## Related

RFC-001, RFC-011, [RFC-016](../016-[partial]-lazy-tab-mounting.md) (lazy mount 5/5), [RFC-024](../024-[partial]-tab-cache-eviction-stale.md) (eviction/stale), [RFC-025](../025-[open]-flat-cinematic-shell.md) (flat cinematic UI), RFC-018 (splash), RFC-019 (god files), [0.8.0 backlog](../backlog/done/0.8.0-[done].md), [0.8.1 backlog](../backlog/done/0.8.1-[done].md)
