# RFC-016: Lazy tab mounting

**Version:** v0.8.x  
**Status:** partial  
**Target version:** [0.8.2](../backlog/done/0.8.2-[done].md) *(shipped)*  
**Area:** `apps/forja/lib/shell/`, tab feature roots

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** acceptance |
| **Current slice** | Busy-tab eviction guards — deferred |
| **Backlog** | — |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred

---

## Acceptance (mount — shipped in code)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R16-A01 | `buildAllScreens()` removed; `navTabBuilders` factory map | ✅ |
| 2 | R16-A02 | First launch: only Home widget tree allocated | ✅ |
| 3 | R16-A03 | Switch to tab: builds once; revisit keeps state until evicted | ✅ |
| 4 | R16-A04 | All nav tabs + Settings still reachable | ✅ |

---

## Acceptance (0.8.2 — eviction + stale)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 5 | R16-A05 | LRU cap (`ShellTokens.maxMountedTabs`); evict oldest non-home, non-current | ✅ |
| 6 | R16-A06 | Navbar hide removes tab from `_mountedTabIds` + `_tabCache` | ✅ |
| 7 | R16-A07 | `ShellTabRefresh` mixin; re-select tab refreshes if past TTL | ✅ |
| 8 | R16-A08 | App resume refreshes visible tab if stale | ✅ |
| 9 | R16-A09 | Home: pull-to-refresh + TMDB/Stremio refetch | ✅ |
| 10 | R16-A10 | Audiobooks: stale refresh on tab focus | ✅ |
| 11 | R16-A11 | Tests: eviction + stale smoke | ✅ |

---

## Summary

Lazy-mount nav tabs on first visit. Cap mounted tabs with LRU eviction. Refresh stale data on re-select, app resume, and pull-to-refresh — without rebuilding unvisited tabs at launch.

## Problem (historical)

Eager `buildAllScreens()` constructed all 19 feature roots at startup. Current code uses `_tabCache` + `_mountedTabIds`, but cache never evicted and data never refreshed after first load.

## Design

### Lazy mount *(shipped)*

- `navTabBuilders` in [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart)
- [`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart): `_tabCache`, `_mountedTabIds`, `ShellBody` + `IndexedStack`

### LRU eviction *(0.8.2)*

- `ShellTokens.maxMountedTabs` (default 5)
- Never evict `home` or currently selected tab
- Evict immediately when tab hidden in navbar settings
- `_tabLru` tracks visit order

### Stale refresh *(0.8.2)*

- [`shell_tab_refresh.dart`](../../apps/forja/lib/shell/shell_tab_refresh.dart) mixin
- `MainScreen._refreshTabIfStale` on tab select + app resume
- Per-tab TTL via `shellStaleAfter` (Home 15m, Audiobooks 10m)
- Home `RefreshIndicator` for force refresh

## Non-goals (0.8.2)

- Busy-tab eviction guards (Music playing, IPTV player) — deferred
- `ShellTabRefresh` on every tab — Home + Audiobooks first

## Related

RFC-011, RFC-017, RFC-023, [0.8.2 backlog](../backlog/0.8.2-[open].md)
