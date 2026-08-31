# RFC-047: Riverpod state migration

**Status:** open  
**Depends on:** RFC-001 (monorepo), RFC-016 (lazy tabs), RFC-024 (tab cache)  
**Area:** `apps/forja` — Flutter host state / async loading  
**Version:** v1.x host DX

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **5 / 5** acceptance (foundation) · **4 / 4** acceptance (shared) · **7 / 7** acceptance (tabs) · **2 / 2** acceptance (details meta) · **2 / 2** acceptance (players status) · **5 / 6** acceptance (deep play/resolve) · **5 / 5** acceptance (settings panels) · **8 / 8** acceptance (TV / leanback async) |
| **Current slice** | Nav-select cloud pull + leanback async on Riverpod — resolve engine loops (R47-A26) remain |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R47-C01 | `ProviderScope` + `flutter_riverpod` (+ annotation/codegen deps) in app root | ✅ |
| 2 | R47-C02 | Shared sync / account / settings providers (`keepAlive`) | ✅ |
| 3 | R47-C03 | In-scope tab async providers (Home → Settings panels) | ✅ |
| 4 | R47-C04 | Media details fetch / sources providers | ✅ |
| 5 | R47-C05 | Selective player providers (not hot position ticks) | ✅ |
| 6 | R47-C06 | Conventions doc (folders, autoDispose, coexistence) | ✅ |

---

## Acceptance (foundation)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R47-A01 | App boots under `ProviderScope` | ✅ |
| 2 | R47-A02 | Provider folder conventions documented in this RFC | ✅ |
| 3 | R47-A03 | Singletons remain backends; providers do not fork truth | ✅ |
| 4 | R47-A04 | Unmigrated screens still compile with coexistence | ✅ |
| 5 | R47-A05 | `flutter analyze` clean on Riverpod touch points | ✅ |

---

## Acceptance (shared reactive domains)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 6 | R47-A06 | `AccountFeatures` exposed via Riverpod; Settings/IPTV can `ref.watch` | ✅ |
| 7 | R47-A07 | Navbar / play-source / addon revision providers; Settings hub + MainScreen watch | ✅ |
| 8 | R47-A08 | Profile `pullAndMergeAll` invalidates shared settings providers | ✅ |
| 9 | R47-A09 | Sync identity revision provider mirrors `SyncService.identityRevision` | ✅ |

---

## Acceptance (in-scope tabs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R47-A10 | Home rails load via `AsyncNotifier` / family; tab refresh invalidates | ✅ |
| 11 | R47-A11 | Search async results via Riverpod | ✅ |
| 12 | R47-A12 | Anime + Asian Drama catalog loads via Riverpod | ✅ |
| 13 | R47-A13 | IPTV controller state via Riverpod (or wrapped notifier) | ✅ |
| 14 | R47-A14 | Live Matches primary async entry via Riverpod | ✅ |
| 15 | R47-A15 | Lists tab async via Riverpod | ✅ |
| 16 | R47-A16 | Settings category panels load via Riverpod | ✅ |

---

## Acceptance (media details)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 17 | R47-A17 | Details meta / recommendations fetch via providers | ✅ |
| 18 | R47-A18 | Details source-resolve status via providers | ✅ |

---

## Acceptance (players)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 19 | R47-A19 | Player source list / resolve status via Riverpod | ✅ |
| 20 | R47-A20 | High-frequency position/buffered stay on `ValueListenableBuilder` | ✅ |

---

## Acceptance (deep play / resolve)

Thin status shells (A17–A19) were not enough — play buttons, torrent/Stremio/Nuvio/Direct, and player sources still owned data in `setState`. This slice moves ownership into session providers.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 21 | R47-A21 | Details play-source flags + torrent/Stremio/Nuvio/webstreaming bag via `detailsPlaySessionProvider` | ✅ |
| 22 | R47-A22 | Details hero Direct / Sources panel watch session (not dual local-only flags) | ✅ |
| 23 | R47-A23 | Desktop + mobile players are `ConsumerStatefulWidget` and watch `playerResolveStatusProvider` | ✅ |
| 24 | R47-A24 | In-player Sources panel publishes to `playerSourcesSessionProvider` | ✅ |
| 25 | R47-A25 | Anime + Asian Drama details primary fetches via Riverpod providers | ✅ |
| 26 | R47-A26 | Move remaining resolve *engine* loops out of details mixins into notifiers (no setState dual-write) | ⬜ |

---

## Acceptance (settings panels)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 27 | R47-A27 | Playback + torrent engine prefs via `settingsPlaybackProvider` / `settingsTorrentProvider` | ✅ |
| 28 | R47-A28 | Debrid + WebStreamr + Jackett/Prowlarr/Nuvio via panel providers | ✅ |
| 29 | R47-A29 | Features navigation via `settingsNavigationProvider` | ✅ |
| 30 | R47-A30 | Trakt / Simkl / MDBlist status via FutureProviders | ✅ |
| 31 | R47-A31 | About crash/analytics/Keychain rows via FutureProviders | ✅ |

---

## Acceptance (TV / leanback async)

TV shares phone/desktop Riverpod for tabs. This slice covers TV-critical residual loads. Focus/hover and hot playback ticks stay local.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 32 | R47-A32 | TV device-link + Who's watching profiles via `tvDeviceLinkSessionProvider` / `syncProfilesProvider` | ✅ |
| 33 | R47-A33 | IPTV player boot prefs + EPG via `iptvPlayerBootPrefsProvider` / `iptvEpgEnabledProvider` (Consumer player) | ✅ |
| 34 | R47-A34 | M3U playlists via `m3uPlaylistsProvider` | ✅ |
| 35 | R47-A35 | Mobile/TV player auto-selection + subtitle prefs via `playerAutoSettingsProvider` / `playerSubtitlePrefsProvider` | ✅ |
| 36 | R47-A36 | Home Trakt + Stremio residual feeds via `home_tracker_providers` | ✅ |
| 37 | R47-A37 | Settings Lists (Trakt/MDBlist) via `external_lists_providers` | ✅ |
| 38 | R47-A38 | Restored-session cold start pulls cloud `profile_settings` (DesktopStartupGate + Android/iOS first-frame force sync) before splash | ✅ |
| 39 | R47-A39 | Side-nav tab select triggers `syncFromCloud` (debounced) — no periodic poll | ✅ |

---

## Summary

Migrate Forja’s Flutter host from ad-hoc `StatefulWidget` + `setState` / `ValueNotifier` async ownership to **Riverpod**, in phases. Cloud sync remains pull-based; Riverpod consumes applied local state. Web realtime is out of scope.

### Conventions

| Rule | Detail |
|------|--------|
| Feature providers | `lib/features/<name>/providers/` |
| Shared providers | `lib/shared/<area>/providers/` |
| Screen-scoped | `autoDispose` (catalog futures, search) |
| Session-long | `keepAlive` / long-lived (auth identity, account features, settings revisions, IPTV controller) |
| UI | `ConsumerWidget` / `ConsumerStatefulWidget` + `ref.watch` / `AsyncValue` |
| Backends | Keep `SyncService`, `SettingsService`, etc. as single source; providers wrap |
| Ephemeral UI | Local `setState` OK (`_expanded`, focus) |
| Hot ticks | Player position/buffered stay on `ValueNotifier` + `ValueListenableBuilder` |
| Codegen | `riverpod_annotation` / `riverpod_generator` available; Phase 1–4 use hand-written `Notifier` / `FutureProvider` APIs |

### Provider map (shipped)

| Area | Path |
|------|------|
| Account features / sync identity / settings revisions / profile pull | `lib/shared/sync/providers/` |
| Home rails | `lib/features/home/providers/home_feed_providers.dart` |
| Search | `lib/features/search/providers/search_providers.dart` |
| Anime | `lib/features/anime/providers/anime_catalog_provider.dart` |
| Asian Drama | `lib/features/asian_drama/providers/asian_drama_providers.dart` |
| IPTV | `lib/features/iptv/providers/iptv_controller_provider.dart` |
| Live Matches | `lib/features/live_matches/providers/live_matches_providers.dart` |
| My List | `lib/features/my_list/providers/my_list_providers.dart` |
| Settings visibility | `lib/features/settings/providers/settings_visibility_provider.dart` |
| Settings panels (playback, debrid, webstreamr, nav, trackers, …) | `lib/features/settings/providers/settings_panel_providers.dart` |
| Stremio addons | `lib/features/settings/providers/stremio_addons_provider.dart` |
| Sync profiles + TV device link | `lib/shared/sync/providers/sync_profiles_provider.dart` |
| IPTV player boot / EPG / M3U | `lib/features/iptv/providers/iptv_player_providers.dart` |
| Player auto + subtitle prefs | `lib/shared/player/providers/player_prefs_providers.dart` |
| Home Trakt / Stremio rails | `lib/features/home/providers/home_tracker_providers.dart` |
| External lists (Trakt / MDBlist) | `lib/features/my_list/providers/external_lists_providers.dart` |
| Details meta / resolve | `lib/features/media/details/providers/details_providers.dart` |
| Details play session (Direct / torrent / Stremio / Nuvio) | `lib/features/media/details/providers/details_play_session.dart` |
| Player resolve status + sources session | `lib/shared/player/providers/player_resolve_providers.dart` |
| Anime details fetches | `lib/features/anime/providers/anime_details_providers.dart` |
| Asian Drama details | `lib/features/asian_drama/providers/asian_drama_providers.dart` |
| ShellBus adapters | `lib/shell/providers/shell_bus_providers.dart` |

### Coexistence

Old `ValueNotifier` / `ChangeNotifier` / `setState` remain where not yet migrated (ephemeral UI, hot player ticks, some panel-local flags). Shared backends stay singletons; providers mirror revisions.

### Non-goals

- Rust engine / FFI replacement
- Web → app Supabase realtime subscribe (follow-up RFC/issue)
- Prioritizing out-of-scope tabs (Arabic, Jellyfin, manga, …)
- Putting every UI flag into Riverpod

### Related

- [RFC-006](006-[partial]-supabase-sync.md) — settings sync
- [RFC-016](016-[partial]-lazy-tab-mounting.md) / [RFC-024](024-[partial]-tab-cache-eviction-stale.md) — tab cache / dispose
- [ARCHITECTURE.md](../ARCHITECTURE.md)
