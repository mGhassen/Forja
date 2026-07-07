# RFC-011: v1.0 — macOS MVP

**Status:** fixed  
**Platforms:** macOS primary; iOS/Android/Windows/Linux runners present

## Goal

Ship Forja as a full cinema app with all PlayTorrio nav tabs, clean monorepo layout, and macOS release build.

## Architecture (shipped)

```
apps/forja/
  lib/app/          bootstrap
  lib/shell/        MainScreen, nav_config, AppRouter, ShellBus
  lib/features/     19 nav tabs + settings
  lib/shared/       player, widgets, Phase 3 stubs
packages/           6 engine packages only
```

Engine packages: `core`, `storage`, `api`, `streaming`, `webstreamr`, `scrapers`.

## Feature scope

| Tab | Feature folder | Engine deps |
|-----|----------------|-------------|
| Home | `features/home/` | tmdb, streaming, stremio |
| Discover | `features/discover/` | tmdb |
| Similar | `features/similar/` | bestsimilar, tmdb |
| Search | `features/search/` | tmdb, stremio |
| My List | `features/my_list/` | trakt, simkl (via api) |
| Downloader | `features/downloader/` | streaming |
| Magnet | `features/magnet/` | libtorrent |
| Live Matches | `features/live_matches/` | api scrapers |
| IPTV | `features/iptv/` | xtream, m3u |
| Audiobooks / Books / Music / Comics / Manga | respective folders | api |
| Jellyfin | `features/jellyfin/` | jellyfin service |
| Anime / Anime Arabic / Asian Drama / Arabic | respective folders | extractors |
| Settings | `features/settings/` | storage |

Player lives in `lib/shared/player/` (not a nav tab). Cross-feature navigation via `AppRouter`.

## v1.0 acceptance checklist

- [x] Feature-first layout under `apps/forja/lib/`
- [x] 19 nav tabs + Settings in `shell/nav_config.dart`
- [x] 6 engine packages; no UI packages in `packages/`
- [x] Root legacy app removed (`lib/`, root platform folders)
- [x] Platform folders under `apps/forja/{macos,ios,android,windows,linux}`
- [x] IPTV Xtream + M3U + portal groups (RFC-002)
- [x] Stremio catalog + torrent playback
- [x] ProviderRegistry core set (RFC-004)
- [x] Unified desktop/mobile player (media_kit)
- [x] PiP (simulated desktop + Android floating)
- [x] Domain-split settings
- [x] `flutter build macos --debug` succeeds
- [ ] macOS release build + notarization (CI: `.github/workflows/build.yml`)
- [x] In-app update check (RFC-015 partial)

## Out of scope (deferred)

- In-player server grid wired to overlay (v1.1 / RFC-003)
- AirPlay / Chromecast (v1.1 / RFC-005)
- Supabase sync (v1.2 / RFC-006)
- Watch party (v1.2+ / RFC-008)
- Web client (v3.0 / RFC-010)

## Related RFCs

RFC-001, RFC-002, RFC-004 (core providers), RFC-021 (release ship hygiene)

## Follow-up (v1.0.1 performance)

Before v1.1 UX work, ship a performance patch: [RFC-016](../016-[draft]-lazy-tab-mounting.md) (lazy tabs), [RFC-017](../017-[draft]-deferred-engine-boot.md) (deferred engines), [RFC-018](../018-[draft]-startup-splash-home.md) (splash + Home stagger).
