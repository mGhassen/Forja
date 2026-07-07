# RFC-016: Lazy tab mounting

**Version:** v1.0.1  
**Status:** draft  
**Target version:** [0.5.1](../backlog/done/0.5.1-[done].md) slice (deferred remainder)  
**Area:** `apps/forja/lib/shell/nav_config.dart`, `apps/forja/lib/shell/main_screen.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 5** acceptance (v1.0.1 slice) |
| **Current slice** | v1.0.1 — lazy tab cache |
| **Backlog** | [0.5.1](../backlog/done/0.5.1-[done].md) slice → deferred |

## Summary

Stop constructing all 19 nav feature widgets at startup. Build each tab on first visit and cache it so `IndexedStack` keeps visited tab state without paying RAM for tabs the user never opens.

## Problem

Today [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) `buildAllScreens()` eagerly returns a `Map<String, Widget>` with every tab instantiated:

```dart
Map<String, Widget> buildAllScreens() => {
  'home': const HomeScreen(),
  'iptv': const IptvPtScreen(),
  // ... 17 more
};
```

[`main_screen.dart`](../../apps/forja/lib/shell/main_screen.dart) stores this map in `initState` and feeds all children to `IndexedStack`.

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

`navMeta` (icons, labels) stays unchanged in [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart).

### Lazy cache in MainScreen

```dart
final Map<String, Widget> _tabCache = {};

Widget _tabAt(int index) {
  final id = _visibleIds[index];
  return _tabCache.putIfAbsent(id, () => navTabBuilders[id]!());
}
```

`IndexedStack` children: unvisited indices can use `SizedBox.shrink()` until first selected, then swap to cached widget.

### State preservation

**Option A (recommended):** Wrap each cached tab in a `KeepAliveTab` wrapper:

```dart
class KeepAliveTab extends StatefulWidget {
  final Widget child;
  // AutomaticKeepAliveClientMixin → wantKeepAlive = true
}
```

**Option B:** Accept re-init on revisit (simpler, worse UX) — document only if Option A is too heavy.

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

## Acceptance

- [ ] `buildAllScreens()` removed or deprecated
- [ ] First launch: only Home widget tree allocated (verify in DevTools)
- [ ] Switch to IPTV: IPTV builds once; revisiting IPTV keeps scroll/state
- [ ] All 19 tabs + Settings still reachable
- [ ] `flutter analyze` clean; macOS smoke test all nav ids

## Related

RFC-011 (v1.0), RFC-017 (defer engines — complementary), RFC-001 (shell owns nav)
