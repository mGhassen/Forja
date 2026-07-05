# RFC-017: Deferred engine boot

**Version:** v1.0.1  
**Status:** Not started

## Summary

Move heavy native and network engines off the critical boot path in [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart). Boot should reach Home quickly; pay for libtorrent, local proxy, and bulk TMDB only when the user needs them.

## Problem

`initEngine()` in bootstrap currently runs in parallel before first paint:

- `TorrentStreamService().start()` — libtorrent native init (slow, can timeout 10s)
- `LocalServerService().start()` — local HTTP proxy
- `MusicPlayerService().init()` — audio stack
- Four TMDB calls: trending, popular, top rated, now playing
- Plus (elsewhere in bootstrap): WebStreamr, Nuvio refresh, AudioService

Users who only browse Home or IPTV still wait for torrent engine startup.

## Goals

- Online cold start: Home interactive in under ~2s on M-series Mac (after RFC-016)
- Offline boot: skip all network engines; app usable for local IPTV/downloads
- Clear UX when a deferred engine fails (snackbar, not silent hang)

## Boot matrix

| Service | Keep on boot | Defer until |
|---------|--------------|-------------|
| `WidgetsFlutterBinding` | yes | — |
| `MediaKit.ensureInitialized` | yes | — (needed early if any video path) |
| `SettingsService` / theme load | yes | — |
| `window_manager` (desktop) | yes | — |
| `Connectivity` check | yes | — |
| `TorrentStreamService.start()` | **no** | First magnet link or torrent play |
| `LocalServerService.start()` | **no** | First stream requiring Referer/proxy |
| `WebStreamrService.init()` | **no** | WebStreamr settings open or first extract |
| `NuvioService.refreshAllInstalled()` | **no** | Nuvio provider selected |
| TMDB bulk prefetch (4 lists) | **no** | Home tab mount (trending first only) |
| `MusicPlayerService.init()` | **no** | Music or Audiobooks tab first visit |
| `AudioService.init()` | **no** | First background audio session |
| `PlayerPoolService` | **no** | First `PlayerScreen` open |

## Design: EngineRegistry

Central lazy initializer in `apps/forja/lib/app/engine_registry.dart` (or `packages/forja_api` if reused):

```dart
class EngineRegistry {
  static final _started = <String>{};

  static Future<void> ensure(String id) async {
    if (_started.contains(id)) return;
    switch (id) {
      case 'torrent':
        await TorrentStreamService().start();
      case 'localServer':
        await LocalServerService().start();
      // ...
    }
    _started.add(id);
  }
}
```

**Call sites:**
- `MagnetPlayerScreen` / torrent play → `ensure('torrent')` + `ensure('localServer')`
- `PlayerScreen` / streaming extract → `ensure('localServer')`
- `HomeScreen.initState` → `ensure('tmdbHome')` (trending only)
- Settings → WebStreamr → `ensure('webstreamr')`

Errors: catch, log `[EngineRegistry] $id failed: $e`, surface once via `ShellBus` or snackbar.

## bootstrap.dart changes

1. Slim `initEngine()` to connectivity + settings + MediaKit (optional defer MediaKit to first play — measure first)
2. Remove `Future.wait` block for torrent/local server/4× TMDB from splash path
3. Keep offline branch: only local music init if needed for downloaded content

## Files to change

| File | Change |
|------|--------|
| [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) | Remove eager engine starts |
| New: `app/engine_registry.dart` | Lazy `ensure()` API |
| Feature entry points | Call `EngineRegistry.ensure` |
| [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) | Own TMDB prefetch (stagger per RFC-018) |

## Acceptance

- [ ] Cold boot does not call `TorrentStreamService.start()` until magnet/torrent used
- [ ] Cold boot does not call `LocalServerService.start()` until stream needs proxy
- [ ] Offline boot completes without network engine calls
- [ ] Magnet tab still works after deferral
- [ ] IPTV / streaming playback still works after deferral
- [ ] Debug log shows deferred init timing

## Related

RFC-016 (lazy tabs), RFC-018 (Home TMDB stagger), RFC-011 (v1.0.1 performance patch)
