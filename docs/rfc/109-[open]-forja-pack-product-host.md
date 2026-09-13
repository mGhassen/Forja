# RFC-109: Forja pack-product host

**Status:** open  
**Depends on:** [RFC-081](fixed/081-[fixed]-host-only-platform-nav-defaults.md) · [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md) · [RFC-088](fixed/088-[fixed]-my-list-pack-only.md) · [RFC-106](fixed/106-[fixed]-forja-foundation-design-system-package.md) · [issue 271](../issues/271-[open]-catalog-body-evacuate-foundation.md)  
**Area:** host architecture / packs / foundation

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **8 / 8** acceptance (law/docs) · **17 / 20** acceptance (code) · **3** 🔄 |
| **Current slice** | A26/A28 landed — no `host/catalog`; layout = PackLayoutHost + hooks + `pack_layout_host_wire.dart`; search painters → `host_search_wire.dart` |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-C01 | Law + cursor rule `forja-pack-product-host.mdc` | ✅ |
| 2 | R109-C02 | Widgets only in `forja_foundation`; `apps/forja/shared/shell` = frame | ✅ |
| 3 | R109-C03 | Dissolve `shared/engine/{hub,lists,live}` → generic `runtime/cache/store/portals/unlock` | ✅ |
| 4 | R109-C04 | `features/iptv` product → pack + `engine/portals` | ✅ |
| 5 | R109-C05 | Generic `ctx.host` (`cache`/`store`/`http`/`vault`/`plugin`/`playback`) — no product `iptv`/`portals` | ✅ |
| 6 | R109-C06 | Packs own live aggregate, list UX, IPTV browse | ✅ |
| 7 | R109-C07 | Grep gates + playback scent strip | ✅ |

---

## Acceptance (law / docs)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A01 | RFC documents pack-product host one-liner + sniff test + target trees | ✅ |
| 2 | R109-A02 | Cursor rule alwaysApply: root forbidden product folder/API names | ✅ |
| 3 | R109-A03 | Community-owned + external-plugins rules link pack-product host | ✅ |
| 4 | R109-A04 | Catalog-hub rule: layout runner in foundation, not host shell | ✅ |
| 5 | R109-A05 | Rules paths cite `forja-packs/{hubs,providers,livesports,iptv,torrent}` | ✅ |
| 6 | R109-A06 | RFC README indexes this RFC | ✅ |
| 7 | R109-A07 | Grep-gate forbidden strings documented | ✅ |
| 8 | R109-A08 | Related RFC-094 / 099 / issue 271 append pointer rows | ✅ |

---

## Acceptance (code waves)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A09 | `PackLayoutHost` mounts foundation layout; no product branches | 🔄 |
| 2 | R109-A10 | Zero `kit_` under `shared/shell` | ✅ |
| 3 | R109-A11 | No dirs `engine/hub`, `engine/lists`, `engine/live`, `features/iptv` | ✅ |
| 4 | R109-A12 | Generic `engine/cache` replaces `MetaCache` | ✅ |
| 5 | R109-A13 | Generic `engine/store` replaces list_follow product API | 🔄 |
| 6 | R109-A14 | Generic `engine/portals` + `forja-packs/hubs/iptv`; no IPTV `coreNav` | ✅ |
| 7 | R109-A15 | No `ctx.host.liveFeed` / product `myList` / product `iptv` namespaces | ✅ |
| 8 | R109-A16 | live_sports pack owns schedule aggregate (no host liveFeed) | ✅ |
| 9 | R109-A17 | Playback has no asian_drama/anime/kisskh behavioral branches outside runPlugin boundary | 🔄 |
| 10 | R109-A18 | Feature docs: IPTV / Live / My List = pack install | ✅ |
| 11 | R109-A19 | Delete host `engine/portals` + `host/portals_ui`; IPTV pack vault/http/playback | ✅ |
| 12 | R109-A20 | `ctx.host.http` / `vault` / `playback.open`; live_sports → iptv `searchChannels` | ✅ |

---

## Acceptance (finish pass)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A21 | No dirs `engine/portals`, `engine/feeds`, `host/portals_ui`, `shell/layout` | ✅ |
| 2 | R109-A22 | Shell `chrome/`/`catalog/` product paint in foundation; shell frame-only | ✅ |
| 3 | R109-A23 | Player details paint in foundation; PackDetailsHost thin wire | ✅ |
| 4 | R109-A24 | live_sports pack owns schedule aggregate (`_feed.js`); no host `feed`/`liveFeed` | ✅ |
| 5 | R109-A25 | Runtime has no `match/` / MatchEvent / live_feed_session product modules | ✅ |
| 6 | R109-A26 | Public `host/layout/` = PackLayoutHost + thin hooks only (`private/` residual Riverpod adapters) | ✅ |
| 7 | R109-A27 | IPTV hub pack browse+play via http/vault/playback (Xtream live MVP) | ✅ |
| 8 | R109-A28 | Host catalog/search MetaItem adapters absorbed into foundation (no `host/catalog` rename residue) | ✅ |

---

## Summary

**One-liner:** Host is capability-only. Packs are product-only. Packs call generic `ctx.host`. The host never owns hub / IPTV / Live Sports / My List screens.

**Sniff test:** If this pack is uninstalled, does this Dart file still make sense as a **generic capability**? No → pack product wrongly in root.

### Law

| Layer | Owns | Forbidden |
|-------|------|-----------|
| **Pack** (`forja-packs`) | Product tabs, layout, feed shaping, product chrome, `open` shaping | Native unlock internals |
| **Host** (`apps/forja`) | App frame, generic engines (`runPlugin`, cache, store, portals, unlock, playback open) | Product screens, product-named folders (`hub`/`lists`/`live`/`iptv`), pack-id business logic |
| **Foundation** (`forja_foundation`) | Widgets + layout protocol/runner | Product domain policy |

### Target trees (finish pass)

```text
apps/forja/lib/shared/engine/
  runtime/  packs/  cache/  store/  vault/  unlock/
  # NO portals/  NO feeds/  NO hub/  NO lists/  NO live/
apps/forja/lib/shared/shell/   # core desktop tv focus brand feedback(toast) chrome(filters)
apps/forja/lib/shared/host/layout/  # PackLayoutHost + thin hooks only
apps/forja/lib/features/       # account + settings only
forja-packs/hubs/iptv          # IPTV product
forja-packs/hubs/live_sports   # schedule aggregate (_feed.js)
```

### Generic `ctx.host` (finish)

| API | Role |
|-----|------|
| `cache.*` | Generic cache |
| `store.*` | Bookmarks / opaque KV |
| `http.request` | Pack HTTP |
| `vault.*` | Encrypted secrets |
| `plugin.list` / `plugin.run` | Pack orchestration |
| `playback.open` | Native play |
| **DELETE** | `liveFeed`, `feed`, product `iptv`/`portals` |

---

## Finish pass notes

| Done | Detail |
|------|--------|
| `engine/portals` + `host/portals_ui` deleted | IPTV pack v1.1+ vault/http/Xtream live browse + play |
| `engine/feeds` deleted | live_sports `_feed.js` aggregate |
| Shell chrome/catalog → foundation | Frame-only shell |
| Player details paint → foundation | PackDetailsHost thin |
| Runtime match/ session/ stremio live deleted | Opaque `LiveSurfaceOpen` tab switch only |
| Public host/layout | PackLayoutHost + hooks + `pack_layout_host_wire.dart` (no `private/`, no `host/catalog`) |
| A28 absorb | Deleted `host/catalog/`; Kit* MetaItem composers colocated in `pack_layout_host_wire.dart`; search painters → `host_search_wire.dart`; CatalogTabs/Menu TV + InteractivePosterCard already in foundation |

| Still open | Detail |
|------------|--------|
| IPTV pack parity | Movies/Series/EPG/Stalker beyond Xtream live MVP |
| A09/A13 | Fat MetaItem/Riverpod composers still live in `pack_layout_host_wire.dart` / `host_search_wire.dart` (~7k LOC) — further paint thinning into foundation continues under A09; list open sheets still under store |

---

## Wave 1 notes (PackLayoutHost)

| Done | Detail |
|------|--------|
| `PackLayoutHost` | `apps/forja/lib/shared/host/layout/pack_layout_host.dart` — extends `KitShell`, zero product branches |
| Nav builders | `PluginNavRegistry` + `MainScreen` key wiring mount `PackLayoutHost` when `pluginId` known |
| KitLiveBoot out of kit_shell | Stack hoist gated by opaque `KitTopBarHostHooks.shouldHoistListBody` (IPTV sets live_schedule) |
| Thin kit wrappers | Moved under `shared/host/layout/` — `kit_tabs` / `menu` / `top_bar` / `portals_chip` / `filter_sheet_option` / `event_dense_tile` are host TV/focus wrappers |
| Zero `kit_` under shell | ✅ — all `kit_*` + catalog product chrome live in `shared/host/layout/` |

| Still open (A09) | Detail |
|------------------|--------|
| Foundation layout paint | `PackLayoutHost` still delegates to `KitShell` body |
| `KitShellLoader` | Async tab→plugin path; returns `KitShell` (avoid import cycle with `pack_layout_host`) |

---

## Wave 2 notes (scent kills)

| Done | Detail |
|------|--------|
| `KitLiveBoot` deleted | Thin `LiveChromeHooks.ensureRegistered` (host/layout) — panel + surface + top-bar only |
| `MetaFeedListSource` deleted | Packs use `PluginFeedSource` → MetaRuntime `feed` (opaque chrome prefs; pack parses horizon) |
| List open scent | `legacy_list_item` / `list_open_binding` opaque `open` only — no anilist/kisskh/asian_drama invent |
| `meta_movie` | No anime/drama/arabic behavioral branches |
| `buildKitTmdbDetailSections` deleted | Details body = pack rails (+ IPTV recs inline) |

| Done (hub dissolve) | Detail |
|---------------------|--------|
| `MetaCache` deleted | Call sites → `EngineCache` (`getEntry`/`putEntry`/`wipePlugin`/…) |
| `engine/hub/` gone | Protocol → `runtime/` (`plugin_actions.dart` keeps class `MetaRuntime`); kit glue → `host/layout/kit/`; `legacy_list_item` → `store/` |
| `hub_plugin_config` | → `runtime/plugin_config.dart` (still used by `plugin_nav`) |
| `legacy_movie_meta` | Kept (call sites) → `runtime/legacy_movie_meta.dart` |

| Still open | Detail |
|------------|--------|
| A16 | ✅ Wave B — pack `_feed.js` aggregate via `ctx.host.plugin.list/run` + `cache`; host `feed`/`liveFeed` deleted |
| A17 | Playback scent strip partial (kisskh sniff / anilist score scope removed; SourceDomain + settings lists remain) |
| A11 | ✅ `hub` / `lists` / `live` / `features/iptv` dirs gone |
| A15 | `liveFeed` deleted; temporary aliases remain: `bookmarks`→`store`, `iptv`→`portals` |

---

## Wave A notes (runtime slim)

| Done | Detail |
|------|--------|
| `live_surface_open.dart` deleted | `LiveChromeHooks` in `host/layout/` — minimal `open.surface: live` → pack tab + panel/top-bar |
| `catalog_list_open.dart` deleted | Feed open/pin inlined in `PluginFeedSource` via `openLegacyListItem` |
| `plugin_hub_feed_source` → `plugin_feed_source` | Opaque chrome prefs (`catalogFilter` / `horizon`); no `LiveFeedQuery` inject |
| `catalog_open` | Removed `live_match` type hardcode branch |
| `open_catalog_search` | Moved to `host/layout/` |
| `play_filters` | Parse stays in runtime; `KitGroupedPlayFilter` → `host/layout/grouped_play_filter.dart` |
| Bridges | `iptv` / `bookmarks` kept until Wave C; `liveFeed`/`feed` removed in Wave B |

| Still open | Detail |
|------------|--------|
| Wave C | portals product UI dissolve; drop remaining deprecated bridges |

---

## Wave 3 notes (lists + live dissolve)

| Done | Detail |
|------|--------|
| `engine/lists/` gone | Persist/follow → `engine/store/` (`list_follow*`, `list_open_prefs`, `list_open_binding`, `list_open_title_rank`) |
| List UI | Picker / bind sheet / flow + Riverpod providers → `shared/engine/store/` (Wave F; `lists_ui/` deleted) |
| `engine/live/` gone | Interim → `engine/feeds/` then Wave B deleted feeds; survivors → `runtime/` / `unlock/` / `portals/match/` / `packs/` |
| `kit_schedule_window` | → `engine/runtime/schedule_window.dart` (+ sheet under `host/layout/`) |
| `embed_webview_proxy` | Deleted (test-only; no production callers) |

| Still open | Detail |
|------------|--------|
| A13 | `ListFollow` still wraps bookmarks; `EngineStore` is the generic surface — migrate callers |
| A16 | ✅ Wave B — pack owns schedule aggregate; `feeds/` deleted |
| C03 | ✅ `feeds/` removed after pack aggregate |

---

## Wave 5+6 notes (generic ctx.host + scent)

| Done | Detail |
|------|--------|
| `ctx.host.cache` | `get` / `set` / `invalidate` → `EngineCache` |
| `ctx.host.store` | `list` / `upsert` / `remove` → `EngineStore` (`bookmarks.list` aliases `store.list`) |
| `ctx.host.portals.searchChannels` | Wires existing `IptvChannelSearch` (`iptv` alias kept) |
| `ctx.host.plugin.list/run` | Wave B — replaces `feed.load` / `liveFeed` for live catalog scrape |
| Packs | `live_sports` → `plugin.*` + `portals.searchChannels`; `my_list` → `store.list` |
| Playback | Stripped kisskh provider sniff / invent-referer; anime score uses opaque tv scope |
| Feature docs + changelog | IPTV / Live / My List = pack install |

---

## Wave B notes (live schedule pack-owned)

| Done | Detail |
|------|--------|
| Pack aggregate | `forja-packs/hubs/live_sports/_feed.js` — list/run catalogs, merge, horizon/sport filter, `ctx.host.cache` |
| Hub feed | `live_sports.js` calls `liveSportsAggregateFeed` — no `host.feed` / `liveFeed` |
| Host bridge | `ctx.host.plugin.list` + `plugin.run` (catalog / resolve / `stremio:` catalog) |
| Nest flag | `hub_host_bridge_nest.dart` — nested `runLiveFeed` skips flutter_js under hub bridge |
| `engine/feeds/` | **Deleted** — survivors relocated (`runtime/live_resolve_streams`, `unlock/live_plugin_engine`, `portals/match/*`, `packs/live_sport_capabilities`) |

| Still open | Detail |
|------------|--------|
| Providers resolve | `live_resolve_streams` still host-owned panel load (next slice → pack `providers` + unlock/playback.open) |
| A15 | Drop `bookmarks` / `iptv` aliases |
| C05 / C06 | `playback.open` + list/IPTV product ownership remain |

## Wave 4 notes (IPTV portals + pack)

| Done | Detail |
|------|--------|
| `engine/portals` | Moved IPTV data / M3U / channel search / EPG **cache** from `features/iptv` |
| `shared/host/portals_ui` | Interim host UI (screens / controller / open / player / EPG cards) — not under `features/` |
| `features/iptv` | **Deleted** — `features/` is account + settings only |
| `hardcoded_channels` | Deleted curated inventory; empty stub types on portals `models.dart` for legacy browse compile |
| `forja-packs/hubs/iptv` | Pack `nav.tabId: iptv` + layout/feed stub → PackLayoutHost |
| coreNav | IPTV removed from `coreNavDestinations` / `coreNavTabBuilders` / `coreShellNavIds` / `addonGatedNavIds` |

| Still open | Detail |
|------------|--------|
| Pack feed rows | Hub feed empty until pack shapes portal list via `ctx.host.portals` |
| portals_ui dissolve | Browse/player leave `portals_ui` when pack layout owns them |

---

## Wave C notes (portals dissolve)

| Done | Detail |
|------|--------|
| Deleted | `apps/forja/lib/shared/engine/portals/` · `apps/forja/lib/shared/host/portals_ui/` |
| Host bridges | `ctx.host.http.request` · `ctx.host.vault.get/set/remove` · `ctx.host.playback.open` |
| Match helpers | Relocated to `engine/runtime/match/` (not IPTV product) |
| IPTV pack | `forja-packs/hubs/iptv` v1.1.0 — settings portal fields, Xtream live categories/channels, `searchChannels`, `open.surface: stream` |
| live_sports | Live TV → `plugin.run(iptv-hub, searchChannels)`; empty sources if no iptv pack |
| Settings | IPTV addon = pack fields + player prefs; CSV portal section removed |
| Sync | Host IptvStore push/pull stubbed — pack vault is local SoT |

| Still open | Detail |
|------------|--------|
| A13 | ListFollow → EngineStore callers |
| A17 | Playback scent strip residual |
| C02 | Shell frame leftovers |

---

## Wave E notes (shell paint → foundation)

| Done | Detail |
|------|--------|
| `shared/shell/chrome/` | **Deleted** — chips / tabs / scroller / section title / tab header → `forja_foundation/widgets/chrome/` |
| `shared/shell/catalog/` | **Deleted** — mood circle + server grid → `forja_foundation/widgets/catalog/` |
| Feedback paint | frosted / fractal / loading dots / card play / error retry → `forja_foundation/widgets/feedback/` |
| TV search browse | → `forja_foundation/widgets/tv/tv_search_browse_overlay.dart` |
| `forja_player_overlay` | → `shared/player/forja_player_overlay.dart` |
| `ShellPaintScope` | Host injects focus/TV via `installShellPaintHostAdapters()` (bootstrap); foundation never imports `package:forja` |
| Toast | Remains `shared/shell/feedback/forja_toast.dart` (host mount) |
| `LoadingOverlay` | Host playback chrome → `shared/playback/loading_overlay.dart` (rust/playback deps — not foundation) |

| Still open (C02) | Detail |
|------------------|--------|
| Shell frame leftovers | `core/` · `chrome/` · `focus/` · `tv/` · `desktop/` · `brand/` stay host |
| Pack mount glue | Fat adapters under `shared/host/layout/private/` (public surface = PackLayoutHost + hooks) |

---

## Wave F notes (`host/layout` + `lists_ui` kill)

| Done | Detail |
|------|--------|
| `lists_ui/` deleted | Open flow / bind sheet / picker / Riverpod providers → `shared/engine/store/` |
| `KitShell` name gone | Body lives in `PackLayoutHost` (same StatefulWidget) |
| Engine glue out | `list_source` / `feed_chrome` / `details_meta*` / `schedule_window` / `open_catalog_search` / … → `engine/runtime/` |
| Player glue out | resolve panel / streams hooks / details play / hero pills / grouped play filter → `player/` |
| `shell/layout/` deleted | Pack adapters → `shared/host/layout/`; frame filters → `shared/shell/chrome/` |
| `PackLayoutHost` | Composes foundation (`CatalogBody` / `CatalogShell` / …) via host/layout MetaItem+TV glue |
| Public `host/layout/` | Only `pack_layout_host.dart` (+ exports `PluginKitTopBar`), `top_bar_host_hooks`, `panel_source_flags_hooks`, `live_surface_open` |
| Fat adapters | Moved under `host/layout/private/` (catalog/search/list/top-bar glue) — not product API |
| Dead chip/sheets | Deleted unused `kit_portals_chip`, `catalog_filter_sheet`, `schedule_window_sheet` (IPTV pack / foundation own paint) |

| Still open | Detail |
|------------|--------|
| Private peel | `private/**` still MetaItem+TV wrappers — further replace with pure foundation props where possible |
| `live_surface_open` | Thin `open.surface: live` + tab handoff — product chrome still pack-owned |

---

## Wave D notes (`player/details` → foundation)

| Done | Detail |
|------|--------|
| Deleted dead paint | `media_details_hero.dart` (zero callers; use `DetailsHero`), `kit_list_status_pin.dart` (use `ListStatusPin`) |
| Moved to foundation | body / scroll / cast / trailers / recs / episode picker / range / air date / watch progress bars |
| Thin host left | `pack_details_host` (was `kit_details_screen`), list status button/hero store wire, match/entry open, play-row TV, scroll TV scope, recs/trailers Movie+player wire, torrent action row, tracker handlers, `sources_panel_tv` |
| Zone A | New `widgets/details/**` paint has **zero** `package:forja/` imports; TV via `ShellPaintScope` |

| Still open | Detail |
|------------|--------|
| Fat host wires | `pack_details_host` / list status button / match page still MetaRuntime + store + TV |
| `kit_details_play_row` | Thin HeroPill / TV scope — not pure paint |
