# RFC-017: Deferred / profile-gated engine boot

**Status:** open  
**Depends on:** [RFC-016](016-[partial]-lazy-tab-mounting.md) (lazy tabs), [RFC-036](036-[open]-accounts-iptv-profile-settings.md) (profile nav + play sources)  
**Area:** `apps/forja/lib/app/bootstrap.dart`, `apps/forja/lib/app/boot_needs.dart`, `apps/forja/lib/app/profile_engine_warm.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** acceptance (first-use lazy) ⏭️ · **8 / 8** acceptance (profile-gated splash) |
| **Current slice** | Profile-gated warm at intro / profile splash — engines follow nav + play sources |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.0.1 first-use lazy)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R17-A01 | Cold boot does not call `TorrentStreamService.start()` until magnet used | ⏭️ |
| 2 | R17-A02 | Cold boot does not call `LocalServerService.start()` until proxy needed | ⏭️ |
| 3 | R17-A03 | Offline boot completes without network engine calls | ⏭️ |
| 4 | R17-A04 | Magnet tab still works after deferral | ⏭️ |
| 5 | R17-A05 | IPTV / streaming playback still works after deferral | ⏭️ |
| 6 | R17-A06 | Debug log shows deferred init timing | ⏭️ |

---

## Acceptance (profile-gated splash)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R17-A07 | `BootNeeds` resolves from navbar + `play_source_*` after profile merge | ✅ |
| 2 | R17-A08 | TMDB BootCache only when `home` / `search` / `mylist` visible | ✅ |
| 3 | R17-A09 | LocalServer + WebStreamr only when Webstreaming on **and** a VOD tab visible | ✅ |
| 4 | R17-A10 | Nuvio refresh + TorrentStream only when Direct torrent on **and** a VOD tab visible | ✅ |
| 5 | R17-A11 | AudioService / Music / Audiobook out of cold boot (tabs on hold) | ✅ |
| 6 | R17-A12 | Home not pre-mounted unless `home` visible; default tab mounts from nav | ✅ |
| 7 | R17-A13 | Profile splash / cold profile select warms engines for incoming profile | ✅ |
| 8 | R17-A14 | Enabling Direct torrent / Webstreaming in Settings warms those engines | ✅ |

---

## Summary

Move heavy native and network engines off the uncritical always-on boot path. **Current slice:** warm only what the active profile has activated (visible tabs + play sources) at intro splash / profile splash.

## Problem

`initEngine()` in bootstrap previously ran in parallel before first paint:

- `TorrentStreamService().start()` — libtorrent native init (slow, can timeout 10s)
- `LocalServerService().start()` — local HTTP proxy
- `MusicPlayerService().init()` — audio stack
- Four TMDB calls: trending, popular, top rated, now playing
- Plus (elsewhere in bootstrap): WebStreamr, Nuvio refresh, AudioService

Users who only browse IPTV still waited for catalog / torrent / music init.

## Goals

- Online cold start: shell interactive without unused engines
- Offline boot: skip network catalog; app usable for local IPTV
- Profile switch: warm engines for the incoming profile during profile splash

## Boot matrix (historical first-use lazy — deferred)

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

## Design: EngineRegistry (historical — deferred)

Central lazy initializer in `apps/forja/lib/app/engine_registry.dart` (or `packages/api` if reused):

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

## bootstrap.dart changes (historical)

1. Slim `initEngine()` to connectivity + settings + MediaKit (optional defer MediaKit to first play — measure first)
2. Remove `Future.wait` block for torrent/local server/4× TMDB from splash path
3. Keep offline branch: only local music init if needed for downloaded content

## Files to change (historical)

| File | Change |
|------|--------|
| [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) | Remove eager engine starts |
| New: `app/engine_registry.dart` | Lazy `ensure()` API |
| Feature entry points | Call `EngineRegistry.ensure` |
| [`home_screen.dart`](../../apps/forja/lib/features/home/home_screen.dart) | Own TMDB prefetch (stagger per RFC-018) |

---

## Slice: profile-gated splash (shipped)

### Boot matrix (current)

| Service | Activates when |
|---------|----------------|
| Host (Flutter, Engine, MediaKit, theme, splash sound) | process start |
| TMDB → BootCache | intro splash **or** profile splash if `home` \| `search` \| `mylist` |
| LocalServer + WebStreamr | intro / profile splash if Webstreaming on **and** VOD tab; settings toggle always |
| Nuvio refresh | intro / profile splash if Direct torrent on **and** VOD tab; settings toggle always |
| TorrentStream | post intro-splash / profile splash if Direct torrent on **and** VOD tab (`home`/`search`/`anime`/`asian_drama`/`mylist`); settings toggle always |
| Stremio Home catalogs | Home mount if Stremio on |
| AudioService / Music / Audiobook | never while tabs on hold |
| Anime / Asian / IPTV / Live / Lists | first tab mount |

### Implementation

| File | Role |
|------|------|
| [`boot_needs.dart`](../../apps/forja/lib/app/boot_needs.dart) | Resolve nav + play sources |
| [`profile_engine_warm.dart`](../../apps/forja/lib/app/profile_engine_warm.dart) | Idempotent warm |
| [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) | Slim Phase 0; gated intro / post-splash |
| [`boot_catalog.dart`](../../apps/forja/lib/app/boot_catalog.dart) | Shared TMDB → BootCache prefetch |
| Profile chooser / switch splash | Warm + catalog after `pullAndMergeAll`; cold pick skips logo intro |
| Settings playback toggles | Warm on enable |

Nuvio is Direct torrent (not webstreaming). WebStreamr + LocalServer are Webstreaming.

## Related

RFC-016 (lazy tabs), RFC-018 (Home TMDB stagger), RFC-011 (v1.0.1 performance patch), RFC-036 (profile settings)
