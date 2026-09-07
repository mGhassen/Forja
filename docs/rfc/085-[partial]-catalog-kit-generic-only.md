# RFC-085: Catalog kit is generic only

**Status:** partial  
**Depends on:** [RFC-070](070-[partial]-catalog-hub-protocol.md) · [RFC-071](fixed/071-[fixed]-live-sports-hub-kit.md) · [RFC-073](fixed/073-[fixed]-live-sports-kit-ownership.md)  
**Area:** `shared/foundation/`, `features/my_list/`, `features/live_sports/`, hub packs

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **22 / 22** acceptance |
| **Current slice** | Peer `shared/tv` → `foundation/tv` (D-pad coordinator / focus graph) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R85-C01 | Kit holds only generic layout/chrome/cards/play — no product folders | ✅ |
| 2 | R85-C02 | `HostListRegistry` outside kit — features register opaque source ids | ✅ |
| 3 | R85-C03 | My List domain under `features/my_list/` | ✅ |
| 4 | R85-C04 | Live Sports domain under `features/live_matches/` | ✅ |

---

## Acceptance (kit evacuation slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R85-A01 | No `my_list/` or `live_schedule/` under `shared/foundation/components/` | ✅ |
| 2 | R85-A02 | No hardcoded `KitListSources.myList` / `.liveSchedule` product switch inside kit | ✅ |
| 3 | R85-A03 | `kit.list` resolves data via host registry + optional opaque `source` / hub `pluginId` — default is not `my_list` | ✅ |
| 4 | R85-A04 | Sources-panel middleware not under a product `kit/sources/` dump folder | ✅ |
| 5 | R85-A05 | Pack layouts compose generic kit widgets; product source ids live in packs/features only | ✅ |
| 6 | R85-A06 | Host tests / imports retargeted to feature paths | ✅ |
| 7 | R85-A07 | `kit.topBar` + action chips and `kit.categoryBar` are generic kit widgets — packs compose them | ✅ |
| 8 | R85-A08 | `kit.list` `open: panel\|details` drives side panel vs generic entry details page — no product-named chrome under features | ✅ |

---

## Acceptance (foundation + live evacuate)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 9 | R85-A09 | `shared/catalog` renamed to `shared/foundation` with shadcn folders (`primitives` / `components` / `blocks` / `protocol` / `services` / `lib`) | ✅ |
| 10 | R85-A10 | `shared/live` deleted — models/helpers in `foundation/lib`, orchestration in `foundation/services/live` | ✅ |
| 11 | R85-A11 | Host has no pack-id live branches (`liveonsat` / `livesoccertv` / streamed·ppv·streamfree menus); packs + opaque `broadcastBySource` only | ✅ |
| 12 | R85-A12 | `foundation/primitives/` holds leaf atoms (`action_chip`, `chip_row`, `underline_tab`, `status_tabs`); composers stay in `components/` | ✅ |
| 13 | R85-A13 | `shared/design` deleted — app-wide atoms live in `foundation/primitives/` (`primitives.dart` barrel); no peer `shared/design` package | ✅ |
| 14 | R85-A14 | Host-owned primitive files use `forja_*` prefix (`forja_action_chip`, `forja_shell_tokens`, …); kit leaf classes `ForjaActionChip` / `ForjaChipRow` / `ForjaUnderlineTab` / `ForjaStatusTabs` | ✅ |
| 15 | R85-A15 | Foundation files/types drop `catalog_` / `hub_` product scent — UI `kit_*` / `Kit*`, protocol `meta_*` / `Meta*` (`KitShell`, `MetaItem`, `MetaRuntime`, …) | ✅ |
| 16 | R85-A16 | App-wide leftover rename: `widgets/kit_details`, `TvKitRow`, `isKitPlugin` / live feed APIs, `PlayContext.metaItem`/`metaOpen`/`kitEpisodes`, `PlayerKitEpisode`, `KitChromeTopBar` | ✅ |
| 17 | R85-A17 | `shared/widgets` deleted — contents under `foundation/primitives` (brand/chrome/tv/desktop) + `foundation/components` (hero/posters/details/media_details/lists/packs/playback/search/update/account); hub re-export shims removed | ✅ |
| 18 | R85-A18 | Foundation UI cards: `LiveMatchCard` / `LiveMatchDenseTile` → `KitEventCard` / `KitEventDenseTile` (`kit_event_*`); no product-named card widgets under `components/` | ✅ |
| 19 | R85-A19 | `components/lists/` deleted — `KitListStatusButton` / `KitListStatusControl` in `chrome/`, `KitListStatusHero` in `hero/`, letter jump in `chrome/letter_jump_scope.dart`; no product `lists/` folder under foundation components | ✅ |
| 20 | R85-A20 | Peer `shared/lists/` deleted — follow + providers under `foundation/services/follow/` (`list_follow.dart` / `ListFollow` / `ListFollowTarget`); no `HubListFollow` alias | ✅ |
| 21 | R85-A21 | Peer `shared/search/` + `components/search/` deleted — `SearchRecentQueries` + `RecentSearchHelperTile` live under `components/chrome/` with `kit_search_*` (not a service) | ✅ |
| 22 | R85-A22 | Peer `shared/tv/` deleted — D-pad stack under `foundation/tv/` (`shell_tv_coordinator`, `shell_tv_focus`, `tv_focus_graph`, …); browse atoms stay in `primitives/tv/` | ✅ |

---

## Summary

**Rule:** `shared/foundation/` is the app-wide UI + hub protocol home. Primitives (tokens, buttons, chips, shell scope, brand, chrome, TV/desktop atoms) and composers (`components/`) live here. D-pad / leanback focus lives under `foundation/tv/`. Product names stay out of kit folders and kit UI types. No peer `shared/live/`, `shared/design/`, `shared/widgets/`, `shared/lists/`, `shared/search/`, or `shared/tv/`. No product folders under `components/` (`lists/`, live-match cards, lone `search/`, …).

**Wrong:** product chrome under `features/live_sports/` named LiveSports*TopBar / LiveSports*Details; `LiveMatchCard` or `MyListButton` under `foundation/components/`; peer `shared/lists/`, `shared/search/`, or `shared/tv/`; pack ids hardcoded in host Dart; design system or shared widgets as siblings of foundation.

**Right:** import atoms from `foundation/primitives/primitives.dart`; packs assemble `kit.topBar` + `kit.categoryBar` + `kit.list { open: panel|details }`; features only register opaque list sources + panel data hosts; live resolve/schedule orchestration lives under `foundation/services/live`.

### Related

- [RFC-073](fixed/073-[fixed]-live-sports-kit-ownership.md) — live schedule kit ownership complete
- [RFC-070](070-[partial]-catalog-hub-protocol.md) — hub protocol
