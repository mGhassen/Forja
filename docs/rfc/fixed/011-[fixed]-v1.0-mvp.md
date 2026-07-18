# RFC-011: v1.0 — macOS MVP

**Version:** v1.0  
**Status:** fixed  
**Target version:** [0.0.1](../backlog/done/0.0.1-[done].md)  
**Platforms:** macOS primary; iOS/Android/Windows/Linux runners present

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** (v1.0 MVP) · **13 / 14** acceptance (notarization → [RFC-021](../021-[draft]-release-ship-hygiene.md)) |
| **Backlog** | [0.0.1](../backlog/done/0.0.1-[done].md) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Acceptance (v1.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R11-A01 | Feature-first layout under `apps/forja/lib/` | ✅ |
| 2 | R11-A02 | 19 nav tabs + Settings in `nav_config.dart` | ✅ |
| 3 | R11-A03 | 6 engine packages; no UI packages in `packages/` | ✅ |
| 4 | R11-A04 | Root legacy app removed | ✅ |
| 5 | R11-A05 | Platform folders under `apps/forja/` | ✅ |
| 6 | R11-A06 | IPTV Xtream + M3U + portal groups (RFC-002) | ✅ |
| 7 | R11-A07 | Stremio catalog + torrent playback | ✅ |
| 8 | R11-A08 | ProviderRegistry core set (RFC-004) | ✅ |
| 9 | R11-A09 | Unified desktop/mobile player (media_kit) | ✅ |
| 10 | R11-A10 | PiP (simulated desktop + Android floating) | ✅ |
| 11 | R11-A11 | Domain-split settings | ✅ |
| 12 | R11-A12 | `flutter build macos --debug` succeeds | ✅ |
| 13 | R11-A13 | macOS release build + notarization (CI) | ⬜ |
| 14 | R11-A14 | In-app update check (RFC-015 partial) | ✅ |

---

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

## Out of scope (deferred)

- In-player server grid wired to overlay (v1.1 / RFC-003)
- AirPlay / Chromecast (v1.1 / RFC-005)
- Supabase sync (v1.2 / RFC-006)
- Watch party (v1.2+ / RFC-008)
- Web client (v3.0 / RFC-010)

## Related RFCs

RFC-001, RFC-002, RFC-004 (core providers), RFC-021 (release ship hygiene)

## Follow-up (v1.0.1 performance)

Before v1.1 UX work, ship a performance patch: [RFC-016](../016-[partial]-lazy-tab-mounting.md) (lazy tabs), [RFC-017](../017-[open]-deferred-engine-boot.md) (deferred / profile-gated engines), [RFC-018](../018-[draft]-startup-splash-home.md) (splash + Home stagger).
