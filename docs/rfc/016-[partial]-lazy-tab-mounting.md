# RFC-016: Lazy tab mounting

**Version:** v0.8.x  
**Status:** partial  
**Target version:** [0.5.1](../backlog/done/0.5.1-[done].md) slice (origin) · mount shipped in code  
**Area:** `apps/forja/lib/shell/nav_config.dart`, `apps/forja/lib/shell/main_screen.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** acceptance (mount) |
| **Current slice** | Complete — eviction/stale in RFC-024 |
| **Backlog** | — (mount); eviction/stale → [RFC-024](024-[partial]-tab-cache-eviction-stale.md) · [0.8.2](../backlog/done/0.8.2-[done].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (mount)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R16-A01 | `buildAllScreens()` removed; `navTabBuilders` factory map | ✅ |
| 2 | R16-A02 | First launch: only Home widget tree allocated | ✅ |
| 3 | R16-A03 | Switch to tab: builds once; revisit keeps state until evicted | ✅ |
| 4 | R16-A04 | All nav tabs + Settings still reachable | ✅ |
| 5 | R16-A05 | `flutter analyze` clean; macOS smoke test all nav ids | ✅ |

---

## Summary

Stop constructing all 19 nav feature widgets at startup. Build each tab on first visit and cache it so `IndexedStack` keeps visited tab state without paying RAM for tabs the user never opens.

Tab cache **eviction** and **stale refresh** are specified in [RFC-024](024-[partial]-tab-cache-eviction-stale.md) — do not conflate with this RFC.

## Problem

Today [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) previously used eager `buildAllScreens()` returning a `Map<String, Widget>` with every tab instantiated:

```dart
Map<String, Widget> buildAllScreens() => {
  'home': const HomeScreen(),
  'iptv': const IptvPtScreen(),
  // ... 17 more
};
```

[`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart) stored this map in `initState` and fed all children to `IndexedStack`.

**Impact:**
- High idle RAM (e.g. `HomeScreen` alone is ~4.8k lines of widget tree logic)
- Slower first interactive frame — Dart builds 19 feature roots before user taps anything
- Wasted work for users who only use Home + IPTV + Settings

## Goals

- Home-only session never allocates IPTV, Jellyfin, Magnet, or other unvisited tab widgets
- Visited tabs preserve scroll position and in-memory state
- No change to nav UX (same 19 tabs + Settings)

## Non-goals

- Removing tabs from the product
- Lazy-loading engine packages (see RFC-017)
- Replacing `IndexedStack` with off-screen route stack
- Tab cache eviction or stale data refresh (see RFC-024)

## Design

### Tab registry (factory map)

Replace eager widgets with builders:

```dart
typedef TabBuilder = Widget Function();

final Map<String, TabBuilder> navTabBuilders = {
  'home': () => const HomeScreen(),
  'iptv': () => const IptvPtScreen(),
  // ...
};
```

`navDestinations` (icons, labels) stays in [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart).

### Lazy cache in MainScreen

```dart
final Map<String, Widget> _tabCache = {};
final Set<String> _mountedTabIds = {'home'};

Widget _tabAt(String id) {
  return _tabCache.putIfAbsent(id, () => navTabBuilders[id]!());
}
```

`ShellBody` + `IndexedStack`: unvisited indices use `SizedBox.shrink()` until first selected, then swap to cached widget.

### State preservation

**Option A (recommended):** Wrap each cached tab in a `KeepAliveTab` wrapper:

```dart
class KeepAliveTab extends StatefulWidget {
  final Widget child;
  // AutomaticKeepAliveClientMixin → wantKeepAlive = true
}
```

**Option B:** Accept re-init on revisit (simpler, worse UX) — document only if Option A is too heavy.

Current code: tabs use `AutomaticKeepAliveClientMixin` where needed (e.g. Search); eviction in RFC-024 resets state on revisit after evict.

### Settings tab

Always build Settings on first open like other tabs — do not eager-load even though it is always in `_visibleIds`.

## Files to change

| File | Change |
|------|--------|
| [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) | `buildAllScreens()` → `navTabBuilders` map |
| [`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart) | Lazy cache + `IndexedStack` builder |
| New: `shell/keep_alive_tab.dart` | Optional wrapper widget |

## Metrics

| Metric | Today (est.) | Target |
|--------|--------------|--------|
| Widgets built at cold start | 19 feature roots | 1 (Home) + shell |
| Idle RAM (macOS, Home only) | High | measurably lower |
| Time to first Home interaction | dominated by all-tab build | no all-tab build |

Measure with Flutter DevTools memory snapshot before/after; log `[MainScreen] Built tab: $id` in debug.

## Related

RFC-011, RFC-017 (defer engines — complementary), RFC-001 (shell owns nav), [RFC-024](024-[partial]-tab-cache-eviction-stale.md) (eviction + stale), [0.8.2 backlog](../backlog/done/0.8.2-[done].md)
