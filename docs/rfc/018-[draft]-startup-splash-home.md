# RFC-018: Startup splash, Home stagger, deferred imports

**Version:** v1.0.1  
**Status:** draft  
**Target version:** [0.5.0](../backlog/done/0.5.0-[done].md), [0.5.1](../backlog/done/0.5.1-[done].md) slices (deferred remainder)  
**Area:** `apps/forja/lib/app/bootstrap.dart`, `apps/forja/lib/features/home/home_screen.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** acceptance (splash / deferred) · **1 ⏭️** stagger · **2 / 2** fetch (A08–A09) · **2 ⏭️** viewport lazy |
| **Current slice** | One TMDB page on open + horizontal page-2 load-more — viewport lazy rails deferred |
| **Backlog** | [0.5.0](../backlog/done/0.5.0-[done].md), [0.5.1](../backlog/done/0.5.1-[done].md) → deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.0.1)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R18-A01 | No fixed minimum splash delay in bootstrap | ⬜ |
| 2 | R18-A02 | Home shows hero/trending before secondary rails populate | ⏭️ |
| 3 | R18-A03 | Palette not run for off-screen posters in initial build | ⬜ |
| 4 | R18-A04 | At least 3 features use deferred import | ⬜ |
| 5 | R18-A05 | No regression in Home content after full load | ⬜ |

---

## Acceptance (catalog lazy load)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R18-A06 | Open Home fetches only hero (trending) + Featured; Popular is +1 preload | ⏭️ |
| 2 | R18-A07 | Viewport arms each later TMDB rail and preloads only the next rail | ⏭️ |
| 3 | R18-A08 | One TMDB page per rail · display cap 20 (full page) | ✅ |
| 4 | R18-A09 | Horizontal near-end loads TMDB page 2 once per discovery row | ✅ |

Viewport-gated rails (R18-A06/A07) caused full-page flash from `VisibilityDetector` + `setState` remounts — reverted. Keep A08 only until a non-flashing stagger lands.

---


## Summary

Remove artificial splash delay, stagger Home API work after first frame, and optionally defer heavy feature libraries from initial Dart load.

## Problem

1. **Splash:** [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) holds a minimum splash duration (~2.8s) while pre-building UI — user waits even when engines finish early.

2. **Home:** [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) (~4.8k lines) fires many parallel `Future`s on init and runs `PaletteGenerator` on posters across rails — CPU and network spike on tab open.

3. **Dart bundle:** All feature libraries parse at startup; no `deferred as` for heavy verticals (IPTV, Jellyfin, etc.).

Assets (~2.5 MB) are not the bottleneck; init work is.

## Goals

- Dismiss splash when Home first frame is ready (not fixed timer)
- Hero + trending visible quickly; secondary rails fill in after ~300ms
- Palette extraction only for visible hero/backdrop
- Reduce initial parse cost for rarely used features

## Non-goals

- Rewriting Home UX
- Core vs Full product flavor (appendix only — not required for v1.0.1)

---

## 1. Splash behavior

**Today:** Native splash + minimum wait + engine init underneath.

**Target:**
1. Show native splash ([`assets/images/splash-*.png`](../../apps/forja/assets/images/))
2. Run slim boot (RFC-017)
3. Mount `MainScreen` with lazy Home (RFC-016)
4. Dismiss splash on `SchedulerBinding.instance.addPostFrameCallback` after Home `build` completes
5. Remove fixed `Duration(seconds: 2)` (or similar) delay

Fallback: max 8s timeout → dismiss anyway with error banner if boot stuck.

## 2. Home stagger

Priority queue in `HomeScreen`:

| Phase | When | Data |
|-------|------|------|
| P0 | `initState` | Trending + hero carousel |
| P1 | +300ms post-frame | Popular, top rated |
| P2 | +600ms | Trakt recommendations, Stremio sections |
| P3 | On scroll / visibility | Palette for off-screen posters via `VisibilityDetector` |

**PaletteGenerator:** only run for hero backdrop and visible carousel item — not every poster in every rail.

**KeepAlive:** after RFC-016, Home state persists when switching tabs — stagger runs once per session.

## 3. Deferred Dart imports

Use `deferred as` for heavy features loaded on first tab visit:

| Library | Deferred alias | Loaded when |
|---------|----------------|-------------|
| IPTV screens | `iptv_lib` | First IPTV tab select |
| Jellyfin | `jellyfin_lib` | First Jellyfin tab |
| Magnet | `magnet_lib` | First Magnet tab |
| Live Matches | `live_lib` | First Live Matches tab |
| Manga / Comics | `manga_lib`, `comics_lib` | First visit |

Pattern in `navTabBuilders` (RFC-016):

```dart
'iptv': () {
  return FutureBuilder(
    future: iptv_lib.loadLibrary(),
    builder: (_, snap) => snap.connectionState == done
        ? iptv_lib.IptvPtScreen()
        : const TabLoadingPlaceholder(),
  );
},
```

**Note:** First visit to a deferred tab shows brief loading indicator — acceptable tradeoff.

## Appendix: Core vs Full flavor (optional, post v1.0.1)

Product flavor excluding `libtorrent_flutter`, `flutter_js`, and Magnet/Downloader tabs for smaller mobile APK. Separate `pubspec` flavor or compile-time `--dart-define=FORJA_CORE=true`. Not in v1.0.1 scope.

## Files to change

| File | Change |
|------|--------|
| [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) | Splash dismiss logic |
| [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) | Staggered futures, palette scope |
| [`nav_config.dart`](../../apps/forja/lib/shell/nav_config.dart) | Deferred imports in builders |
| New: `shared/widgets/tab_loading_placeholder.dart` | Shimmer for deferred tab load |

## Metrics

| Metric | Target |
|--------|--------|
| Splash visible time | ≤ boot work duration (no artificial +2.8s) |
| Home hero visible | first frame after tab mount |
| TMDB requests at Home open | 1 (trending), not 4 |


## Related

RFC-016, RFC-017, RFC-011 (v1.0.1)
