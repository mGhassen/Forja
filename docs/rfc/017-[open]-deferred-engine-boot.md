# RFC-017: Deferred / profile-gated engine boot

**Status:** open  
**Depends on:** [RFC-016](016-[partial]-lazy-tab-mounting.md) (lazy tabs), [RFC-036](036-[open]-accounts-iptv-profile-settings.md) (profile nav + play sources)  
**Area:** `apps/forja/lib/app/bootstrap.dart`, `apps/forja/lib/app/boot_needs.dart`, `apps/forja/lib/app/profile_engine_warm.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 6** acceptance (first-use lazy) ⏭️ · **8 / 8** acceptance (profile-gated splash) · **3 / 3** acceptance (profile-switch = intro) · **4 / 4** acceptance (instant splash + post-splash engines) · **3 / 3** acceptance (pack-gated splash) |
| **Current slice** | Splash awaits ForjaHQ packs + default hub prefetch; play-source engines still post-dismiss |

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

## Acceptance (profile-switch = intro)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R17-A15 | Profile switch splash dismisses at motion floor even if warm/TMDB still running (same as intro `_dismissWhenReady`) | ✅ |
| 2 | R17-A16 | Profile switch warm uses `startTorrent: false`; torrent starts post-dismiss | ✅ |
| 3 | R17-A17 | `pullAndMergeAll` pulls IPTV portals only when `iptv` is in navbar; otherwise clears local IPTV cache (no bleed, no network) | ✅ |

---

## Acceptance (instant splash + post-splash engines)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R17-A18 | `DesktopStartupGate` paints splash/account from cached session on first frame (no blank update stage) | ✅ |
| 2 | R17-A19 | Update check + `pullAndMergeAll` (incl. IPTV) run in background after first paint; soft-fail keeps local | ✅ |
| 3 | R17-A20 | Intro / profile splash uses `startPlaySources: false`; LocalServer / WebStreamr / Nuvio / Torrent start post-dismiss | ✅ |
| 4 | R17-A21 | Home does not fetch or render Stremio catalog rails | ✅ |

---

## Acceptance (pack-gated splash)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R17-A22 | Intro / profile splash **awaits** official ForjaHQ packs (6 required; Arabic optional) before dismiss | ✅ |
| 2 | R17-A23 | Splash prefetches default hub `layout` (Home, else first visible hub) into CatalogCache | ✅ |
| 3 | R17-A24 | LocalServer / WebStreamr / Nuvio / Torrent still start **post**-dismiss (unchanged) | ✅ |

---

## Summary

Move heavy native and network engines off the uncritical always-on boot path. **Current slice:** logo splash paints immediately; **awaits ForjaHQ pack install + default hub layout prefetch** before dismiss; Sources engines (proxy, WebStreamr, Nuvio, torrent) start after splash dismiss.

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
| Logo / account UI | **first frame** from cached session (update + cloud pull background) |
| TMDB → BootCache | intro splash **or** profile splash if `home` \| `search` \| `mylist` |
| LocalServer + WebStreamr | **post** intro / profile splash if Webstreaming on **and** VOD tab; settings toggle always |
| Nuvio refresh | **post** intro / profile splash if Nuvio on **and** VOD tab; settings toggle always |
| TorrentStream | **post** intro / profile splash if Direct torrent on **and** VOD tab; settings toggle always |
| Stremio Home catalogs | **removed** (Search / details / Live Matches only for now) |
| AudioService / Music / Audiobook | never while tabs on hold |
| Anime / Asian / IPTV / Live / Lists | first tab mount |

### Implementation

| File | Role |
|------|------|
| [`boot_needs.dart`](../../apps/forja/lib/app/boot_needs.dart) | Resolve nav + play sources |
| [`profile_engine_warm.dart`](../../apps/forja/lib/app/profile_engine_warm.dart) | Idempotent warm |
| [`bootstrap.dart`](../../apps/forja/lib/app/bootstrap.dart) | Slim Phase 0; gated intro / post-splash |
| [`boot_catalog.dart`](../../apps/forja/lib/app/boot_catalog.dart) | Shared TMDB → BootCache prefetch |
| Profile chooser / switch splash | After `pullAndMergeAll`: warm like intro (`startTorrent: false` + TMDB); dismiss at 5s floor even if warm still running; torrent post-dismiss |
| Settings playback toggles | Warm on enable |

Nuvio is Direct torrent (not webstreaming). WebStreamr + LocalServer are Webstreaming.

### Profile-switch = intro (R17-A15–A17)

Mid-session / cold Who’s watching no longer blocks the avatar splash on full warm + TMDB + always-on IPTV pull:

1. **Required before dismiss:** save prior profile (if mid-session), `selectProfile`, lean `pullAndMergeAll` (settings only unless `iptv` nav).
2. **Under the floor (like intro):** `ProfileEngineWarm(startTorrent: false)` + optional TMDB prefetch.
3. **Hard cap:** when the 5s motion floor elapses, pop the splash and keep warm/TMDB alive in the background.
4. **IPTV:** pull portals only if navbar contains `iptv`; otherwise empty local cache so the previous profile cannot bleed.

## Related

RFC-016 (lazy tabs), RFC-018 (Home TMDB stagger), RFC-011 (v1.0.1 performance patch), RFC-036 (profile settings)
