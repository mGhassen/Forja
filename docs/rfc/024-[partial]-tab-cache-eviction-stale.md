# RFC-024: Tab cache eviction & stale refresh

**Version:** v0.8.x  
**Status:** partial  
**Target version:** [0.8.2](../backlog/done/0.8.2-[done].md) *(shipped)*  
**Depends on:** [RFC-016](016-[partial]-lazy-tab-mounting.md) (lazy mount)  
**Area:** `apps/forja/lib/shell/`, tab feature roots

## Status at a glance

| | |
|--|--|
| **Progress** | **15 / 16** acceptance · **1** deferred |
| **Current slice** | R24-A04 global busy registry — deferred |
| **Backlog** | — |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (eviction — 0.8.2)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R24-A01 | LRU cap (`ShellTokens.maxMountedTabs`); evict oldest non-home, non-current | ✅ |
| 2 | R24-A02 | Navbar hide removes tab from `_mountedTabIds` + `_tabCache` | ✅ |
| 3 | R24-A03 | Never evict `home` or currently selected tab | ✅ |
| 4 | R24-A04 | Busy-tab eviction guards (Music playing, IPTV player) | ⏭️ |
| 5 | R24-A05 | Tests: navbar hide eviction smoke | ✅ |

---

## Acceptance (stale infrastructure — 0.8.2)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 6 | R24-A06 | `ShellTabRefresh` mixin in `shell_tab_refresh.dart` | ✅ |
| 7 | R24-A07 | Re-select tab runs `refreshIfStale` when past TTL | ✅ |
| 8 | R24-A08 | App resume refreshes visible tab if stale | ✅ |

---

## Acceptance (per-tab stale — screen by screen)

| # | ID | Tab | Policy | Status |
|--:|----|-----|--------|--------|
| 9 | R24-A09 | Home | Pull-to-refresh + TMDB/Stremio refetch; TTL 15m | ✅ |
| 10 | R24-A10 | Audiobooks | `ShellTabRefresh` on focus; TTL 10m | ✅ |
| 11 | R24-A11 | Search | Query-driven only — no auto stale refetch | ✅ |
| 12 | R24-A12 | My List | Event-driven via `MyListService`; optional focus refresh | ✅ |
| 13 | R24-A13 | Settings | Local prefs only — no API stale policy | ✅ |
| 14 | R24-A14 | IPTV / Discover | `ShellTabRefresh` + IPTV `shellBlocksEviction` when deep | ✅ |
| 15 | R24-A15 | Music | `ShellTabRefresh` + playback eviction guard | ✅ |
| 16 | R24-A16 | Jellyfin | `ShellTabRefresh` on focus | ✅ |

---

## Summary

Separate **widget cache** (RAM) from **data freshness** (TTL). Cap mounted tabs with LRU eviction; refresh stale data on re-select, app resume, and pull-to-refresh — per tab, not one global knob.

## Problem (historical)

After RFC-016 mount shipped, `_mountedTabIds` only grew and `_tabCache` never cleared. Hidden navbar tabs stayed allocated. Visited tabs never refetched data after first load.

## Design

### LRU eviction

- `ShellTokens.maxMountedTabs` (default 5)
- `_tabLru` tracks visit order; `_evictTab` removes from cache + mount set
- Never evict `home` or currently selected tab
- Evict immediately when tab hidden in navbar settings

### Stale refresh

- [`shell_tab_refresh.dart`](../../apps/forja/lib/shell/shell_tab_refresh.dart) mixin
- `MainScreen._refreshTabIfStale` on tab select + app resume
- Per-tab TTL via `shellStaleAfter` override
- Home `RefreshIndicator` for force refresh

### Per-tab TTL defaults

| Tab | TTL | Auto refresh on re-select |
|-----|-----|---------------------------|
| Home | 15m | Yes |
| Audiobooks | 10m | Yes |
| Search | — | No (query-driven) |
| My List | event | Optional on focus |
| Settings | — | No |
| IPTV / Music / Jellyfin | 10–15m | Yes |

## Non-goals

- Replacing lazy mount (RFC-016)
- Refetch all mounted tabs on every switch
- Home god-file split (RFC-019)

## Related

RFC-016, RFC-023, RFC-018 (Home stagger), [0.8.2 backlog](../backlog/done/0.8.2-[done].md)
