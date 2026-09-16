# RFC-109: Forja pack-product host

**Status:** open  
**Depends on:** [RFC-081](fixed/081-[fixed]-host-only-platform-nav-defaults.md) · [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md) · [RFC-088](fixed/088-[fixed]-my-list-pack-only.md) · [RFC-106](fixed/106-[fixed]-forja-foundation-design-system-package.md) · [issue 271](../issues/271-[open]-catalog-body-evacuate-foundation.md)  
**Area:** host architecture / packs / foundation

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **8 / 8** acceptance (law/docs) · **26 / 29** acceptance (code) · **4** 🔄 · **8 / 8** IPTV unified pack (A35–A40 · A53–A54) · **12 / 12** A41 pack migrate · **3 / 3** host/layout wipe (A57–A59) · **3 / 3** foundation layout evacuate (A60–A62) · **3 / 3** validate+paint (A63–A65) · **3 / 3** pack-owned search (A66–A68) · **4 / 4** catalog slot paint (A69–A72) · **4 / 4** live guide paint (A73–A76) · **2 / 2** guide out of player (A82–A83) · **3 / 3** pack-owned portal forms (A84–A86) · **1 / 1** runtime action wires (A87) · **4 / 5** empty-shell chassis (A77–A81 · A79 🔄) |
| **Current slice** | Empty-shell chassis — brand/bus peel landed; A79 remaining (toast / ForjaInteractive / scaffold → foundation). Guide adapters moved to `engine/portals/guide/`. Portal Add/Edit/Import forms are pack-declared. `runtime/chrome/` split → `actions/` + `kit/hosts/`. |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-C01 | Law + cursor rule `forja-pack-product-host.mdc` | ✅ |
| 2 | R109-C02 | Widgets + brand + empty-shell frame in `forja_foundation`; `apps/forja/lib/shell` = chassis wire only | 🔄 |
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
| 1 | R109-A09 | `PackLayoutHost` mounts foundation layout; no product branches | ✅ |
| 2 | R109-A10 | Zero `kit_` under `shell` | ✅ |
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
| 9 | R109-A29 | No `engine/runtime/details/` — meta protocol helpers in foundation; host wire beside PackDetailsHost only | ✅ |
| 10 | R109-A30 | Stremio details load + rail open/TV wire stay host debt (`engine/details/details_stremio` · `details_host_wire`) until pack owns surface | 🔄 |
| 11 | R109-A31 | No `engine/runtime/list/` — kit.list host wire in `host/layout/list`; Live Sports paint/search/schedule in pack | ✅ |
| 12 | R109-A32 | `plugin_feed_source` / Riverpod list open mode stay host layout debt until pack owns feed | 🔄 |
| 13 | R109-A33 | Foundation has no Live Sports product (`list_event_paint` / `match` / `schedule_window` / `kit_list_entry`) — pack emits flat paint + `searchText` | ✅ |
| 14 | R109-A34 | Details upcoming/premiereLabel emitted by pack `hubStampDetailsPaint`; host reads only; foundation `meta_details` deleted | ✅ |

---

## Acceptance (IPTV unified pack)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A35 | `forja-packs/hubs/iptv` ships hub nav + `iptv-vod` details + enrich in one pack | ✅ |
| 2 | R109-A36 | Official catalog publishes `hubs/iptv` (`plugin_packs.id=iptv`); `iptv-vod` catalog row removed | ✅ |
| 3 | R109-A37 | Host Addons IPTV row pack-only (`settings.addon`); `addonGatedNavIds` empty; install activates tab | ✅ |
| 4 | R109-A38 | Pack feed Live / Movies / Series (Xtream categories + streams); VOD details fetch series episodes | ✅ |
| 5 | R109-A39 | Thin host `PackIptvPlayHooks` — vault portal → Xtream URL → `HostPlaybackOpen` (no portals_ui) | ✅ |
| 6 | R109-A40 | Portals panel / Stalker / M3U / EPG guide / dedicated IPTV player chrome parity | ✅ |
| 7 | R109-A41 | Replace interim host `IptvPtScreen` / `portals_ui` with pack-owned chrome (A19/A21 law) | ✅ |
| 8 | R109-A42 | Host `engine.request` + `playback.probe` + durable `cache.disk*` (no `host.iptv`) | ✅ |
| 9 | R109-A43 | Vault SoT + one-shot `IptvStore` → `iptv.portals` migrate + dual-write | ✅ |
| 10 | R109-A44 | Flip nav: `iptv` tab mounts `PackLayoutHost` (no `IptvPtScreen`) | ✅ |
| 11 | R109-A45 | Pack layout/feed: portals action + Live/Movies/Series + prefs/platforms modules | ✅ |
| 12 | R109-A46 | Foundation paint: EPG guide + catalog split + PortalListPanel slots | ✅ |
| 13 | R109-A47 | Pack portals product chrome (replace Flutter portal panel) | ✅ |
| 14 | R109-A48 | Pack EPG browse mode wired to foundation guide | ✅ |
| 15 | R109-A49 | Player generic live path; delete remaining product `portals_ui` | ✅ |
| 16 | R109-A50 | Delete product Dart orchestration; sync/FFI adapters only | ✅ |
| 17 | R109-A51 | Feature docs + changelog match pack-mounted IPTV | ✅ |
| 18 | R109-A52 | Remount exact `IptvPtScreen` catalog UX until pack/foundation catalog chrome parity (shelf/search/sort/cats/channels/EPG) | ✅ |
| 19 | R109-A53 | Merge VOD `details` into `iptv-hub` — drop separate `iptv-vod` plugin; enrich stays companion | ✅ |
| 20 | R109-A54 | Host opens IPTV movie/series details via hub plugin id (tab / engine type) | ✅ |
| 21 | R109-A55 | Pack layout: search / sort / view chrome; feed `q` + `sort` params (Live Sports kit model) | ✅ |
| 22 | R109-A56 | Host `PortalsChromeHooks` — pack `listPortals` / select / add / remove; no `IptvController` | ✅ |

---

## Acceptance (host/layout wipe)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A57 | Law: wipe entire `apps/forja/lib/shared/host/layout/` — layout runner lives in `forja_foundation`; product chrome/feed/details in pack JS only | ✅ |
| 2 | R109-A58 | Pack `listPortals` returns foundation-paintable `items` + `layout`; host portals panel is generic paint (no product inventory logic beyond `runPlugin`) | ✅ |
| 3 | R109-A59 | `live_sports` pack owns progressive catalog fan-out in `_feed.js`; delete host `live_schedule_progressive.dart` (schedule list = `PluginFeedSource` + pack feed) | ✅ |

---

## Acceptance (foundation layout evacuate)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A60 | Evacuated `packages/forja_foundation/lib/layout/` → `apps/forja/lib/shared/engine/runtime/kit/` — DS paint-only; no `host/layout/` parking | ✅ |
| 2 | R109-A61 | Law + cursor rule: foundation forbids PackLayoutHost/hooks/Riverpod kit session; host owns thin kit interpreter | ✅ |
| 3 | R109-A62 | Foundation pubspec drops Riverpod/shared_preferences/visibility_detector; barrel no longer exports PackLayoutHost | ✅ |

---

## Summary

**One-liner:** Empty shell + engines. Packs are product. Foundation is a design system (paint only). Packs call `ctx.host` / `runPlugin`.

**Sniff test:** If this pack is uninstalled, does this Dart file still make sense as a **generic capability**? No → pack product wrongly in root. Foundation: would this belong in a shadcn-style DS? No → host engine or pack.

### Law

| Layer | Owns | Forbidden |
|-------|------|-----------|
| **Pack** (`forja-packs`) | Product tabs, layout JSON, feed, prefs, chrome, `open` shaping | Native unlock internals |
| **Host** (`apps/forja`) | App frame, generic engines, **thin kit interpreter** at `shared/engine/runtime/kit/` | Product screens, product-named folders, pack-id business logic, **`shared/host/layout/`** |
| **Foundation** (`forja_foundation`) | Tokens (incl. ThemeExtension), components, widgets, blocks, protocol **types** | `PackLayoutHost`, hooks, Riverpod kit session, registries, feed orchestration |

**Wipe law (A57 historical):** Deleted `apps/forja/lib/shared/host/layout/`. **Evacuate (A60):** runner left foundation — lives in `engine/runtime/kit/`. Product stays in pack JS. Foundation paints only.

### Target trees (finish pass)

```text
apps/forja/lib/shared/engine/
  runtime/kit/   # thin kit interpreter (PackLayoutHost + wire + list/feed hooks)
  runtime/  packs/  cache/  store/  vault/  unlock/
  # NO portals/  NO feeds/  NO hub/  NO lists/  NO live/
apps/forja/lib/shell/   # frame (nav/frame/routing/bus/chrome) + core desktop tv focus brand feedback filters update
apps/forja/lib/shared/host/    # NO layout/ (parking forbidden)
apps/forja/lib/features/       # account + settings only
packages/forja_foundation/     # paint only — NO lib/layout/
forja-packs/hubs/iptv          # IPTV product (layout/feed/details/listPortals)
forja-packs/hubs/live_sports   # schedule aggregate + progressive fan-out (_feed.js)
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
| `hub_plugin_config` | → `runtime/meta/plugin_config.dart` (still used by `plugin_nav`) |
| `legacy_movie_meta` | Kept (call sites) → `runtime/open/legacy_movie_meta.dart` |

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
| `kit_schedule_window` | → pack `live_sports` horizon menu (Dart schedule_window deleted) |
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

### Evacuate notes (path 1 — pack-owned like Live Sports)

| Done | Detail |
|------|--------|
| Nav | `plugin_nav` → `PackLayoutHost` only (no `IptvPtScreen` / tabId branch) |
| Deleted | `shared/host/portals_ui/**` (browse + controller) |
| Pack | `hubs/iptv` v1.5.0 layout: catalog/sort/search/view/portals + feed `q`/`sort` |
| Portals chrome | `host/layout/portals/portals_chrome_hooks.dart` → pack `listPortals` / add / select / remove |
| Player | `shared/player/iptv/**` (playback + channel guide + open hooks) |

| Still open | Detail |
|------------|--------|
| A47 | Pack returns `listPortals` `items`/`layout`; Flutter `PortalListPanel` host wire still product-shaped (`portals_action_host.dart`) |
| A48 | Pack EPG browse mode → foundation `EpgGuide` |
| A50 | Fat `PackLayoutHost` / wire / progressive still under `shared/host/layout/` (~7k lines) — not sync/FFI-only |
| A57–A59 | Wipe `host/layout/`; foundation owns runner; pack owns progressive + portals paint data |
| Kit gaps | Category pin/reorder, channel health borders, scrape ticker parity vs old Flutter chrome |

---

## Wave C notes (portals dissolve)

| Done | Detail |
|------|--------|
| Deleted | `apps/forja/lib/shared/engine/portals/` · `apps/forja/lib/shared/host/portals_ui/` |
| Host bridges | `ctx.host.http.request` · `ctx.host.vault.get/set/remove` · `ctx.host.playback.open` |
| Match helpers | Relocated to `engine/runtime/match/` (not IPTV product) |
| IPTV pack | `forja-packs/hubs/iptv` — hub nav + `details` + enrich companion; catalog id `iptv` |
| live_sports | Live TV → `plugin.run(iptv-hub, searchChannels)`; empty sources if no iptv pack |
| Settings | IPTV Addons row only when pack installed (pack `settings.addon`); player prefs still under that page; no host Addons master toggle / `addonGatedNavIds` |
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
| `shell/chrome/` | **Deleted** — chips / tabs / scroller / section title / tab header → `forja_foundation/widgets/chrome/` |
| `shell/catalog/` | **Deleted** — mood circle + server grid → `forja_foundation/widgets/catalog/` |
| Feedback paint | frosted / fractal / loading dots / card play / error retry → `forja_foundation/widgets/feedback/` |
| TV search browse | → `forja_foundation/widgets/tv/tv_search_browse_overlay.dart` |
| `forja_player_overlay` | → `shared/player/forja_player_overlay.dart` |
| `ShellPaintScope` | Host injects focus/TV via `installShellPaintHostAdapters()` (bootstrap); foundation never imports `package:forja` |
| Toast | Was host `shell/feedback/forja_toast.dart` — migrate paint to foundation (A79) |
| `LoadingOverlay` | Host playback chrome → `shared/playback/loading_overlay.dart` (rust/playback deps — not foundation) |

| Still open (C02 → empty-shell) | Detail |
|--------------------------------|--------|
| Paint leave host | Brand, toast paint, focus primitives, nav rail/scaffold → `forja_foundation` ([issue 280](../issues/280-[open]-empty-shell-chassis.md) · A77–A81) |
| Chassis only | App keeps pack-nav wire, platform, OTA, thin paint-host adapters — **not** product chrome |
| Pack mount glue | Fat adapters under `shared/host/layout/private/` (public surface = PackLayoutHost + hooks) |

| Historical (superseded) | Detail |
|-------------------------|--------|
| Old Wave E leftover | Claimed `core/` · `chrome/` · `focus/` · `tv/` · `desktop/` · `brand/` stay host — **wrong**; empty-shell law moves paint to foundation |

---

## Wave F notes (`host/layout` + `lists_ui` kill)

| Done | Detail |
|------|--------|
| `lists_ui/` deleted | Open flow / bind sheet / picker / Riverpod providers → `shared/engine/store/` |
| `KitShell` name gone | Body lives in `PackLayoutHost` (same StatefulWidget) |
| Engine glue out | `list_source` / `feed_chrome` / `details_meta*` / `schedule_window` / `open_catalog_search` / … → `engine/runtime/` |
| Player glue out | resolve panel / streams hooks / details play / hero pills / grouped play filter → `player/` |
| `shell/layout/` deleted | Pack adapters → `shared/host/layout/`; frame filters → `shell/chrome/` |
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
| Relocate (later) | Host wire left `player/details/` → `shared/engine/details/` (not under player; does not revive deleted `engine/runtime/details/`) |

| Still open | Detail |
|------------|--------|
| Fat host wires | `pack_details_host` / list status button / match page still MetaRuntime + store + TV |
| `kit_details_play_row` | Thin HeroPill / TV scope — not pure paint |

---

## Wave G notes (`engine/runtime/details` evacuate)

| Done | Detail |
|------|--------|
| Deleted | `apps/forja/lib/shared/engine/runtime/details/` |
| Foundation | `protocol/meta_details.dart` (upcoming / params / episode maps / surface flags) · `widgets/details/pack_detail_meta.dart` (rails parse / backdrops / facts) |
| Host debt left | `engine/details/details_fetch.dart` (MetaRuntime run) · `details_stremio.dart` · `details_host_wire.dart` (nav tab resolve / rail open+TV / rust trailers) |

| Still open | Detail |
|------------|--------|
| A30 | Stremio details + host rail wire → pack surface or thinner host callbacks |

---

## Wave H notes (`engine/runtime/list` evacuate)

| Done | Detail |
|------|--------|
| Deleted | `apps/forja/lib/shared/engine/runtime/list/` |
| Foundation | (none — orphan `kit/row_prefetch.dart` deleted; no consumers) |
| Host layout | `host/layout/list/` — registry, panel, Riverpod query/open, `plugin_feed_source`, thin `KitListPaint` reader |
| Pack (Live Sports) | `liveSportsShapeRow` emits flat paint + `timeLabel`/`scheduleLabel`/`searchText`; feed accepts `q` |

| Still open | Detail |
|------------|--------|
| A32 | Feed source + open-mode providers → thinner host / pack |

---

## Wave I notes (foundation product eviction)

| Done | Detail |
|------|--------|
| Deleted from foundation | `kit/list_event_paint.dart` · `kit/list_event_match.dart` · `protocol/kit_list_entry.dart` · `protocol/schedule_window.dart` |
| Pack owns | schedule horizon prefs (already) · row paint · search haystack |
| Host | reads pack fields only via `KitListPaint.fromKitEntry` |

| Still open | Detail |
|------------|--------|
| A30 | Stremio details + host rail wire |
| `meta_details` in foundation | still hub-shaped — later peel |

---

## Wave J notes (details paint → packs)

| Done | Detail |
|------|--------|
| Pack | VOD hub `_kit.js`: `hubStampDetailsPaint` on `hubOk('details')` + `hubItems` → `upcoming`, `premiereLabel` (not live_sports / my_list) |
| Protocol | `MetaItem.upcoming` · `MetaItem.premiereLabel` |
| Host | `engine/details/details_meta.dart` reads pack fields only |
| Deleted | `forja_foundation/protocol/meta_details.dart` |

| Still open | Detail |
|------------|--------|
| A30 | Stremio details load still host |
| `pack_detail_meta` | generic rails/facts/backdrops readers — keep |

---

## Related (composition)

- [RFC-110](110-[draft]-pack-surface-contributions.md) — packs declare surface slots (details / player chrome) without remapping open identity; layers on this pack-product host law

---

## Wave K notes (pack JS parity + host/layout wipe law)

| Done | Detail |
|------|--------|
| IPTV pack | `listPortals` returns `items` + `layout` (portalList); `details` fills `meta.videos` via engine `series_episodes` / Xtream HTTP (replaces deleted Dart episode list) |
| live_sports | `_feed.js` owns sequential catalog fan-out; host `liveScheduleFeedProvider` calls hub `feed` once (no host progressive fan-out) |
| Law | **`apps/forja/lib/shared/host/layout/` wiped** — runner in foundation; host bridge `engine/runtime/layout/pack_layout_host_bridge.dart`; product in pack JS (A57) |
| Portals hoist | Opaque `PortalsActionHost.registerHoistSource` + foundation hoist when layout topBar declares `action: portals` (no `iptv`/`portals` product ids) |
| A48 | Kit list View cycles Cards/List/Timeline; generic `style: timeline` paints foundation guide from pack-emitted `programmes` (not IPTV-specific wire) |
| Pin order | Category bar keeps pack feed first-seen order; IPTV pack sorts streams by `pinnedCats` first |
| Generic scent | No `Iptv*` aliases / `live_schedule` const / `portals` hardcodes in foundation layout; inventory chip + opaque hoistSource |
| A26 / A31 | Historical ✅ described `host/layout/` paths — frozen; wipe done (paths now foundation + engine bridge) |

| Still open | Detail |
|------------|--------|
| A50 | Fat `pack_layout_host_bridge.dart` still hosts orchestration (sync/FFI + layout wire) — not sync/FFI-only yet |

---

## Wave L notes (foundation layout evacuate)

| Done | Detail |
|------|--------|
| A60 | `forja_foundation/lib/layout/*` → `apps/forja/lib/shared/engine/runtime/kit/`; deleted foundation layout zone + `forja_foundation_layout.dart` |
| A61 | `forja-pack-product-host.mdc`: DS = paint; host = thin interpreter under `runtime/kit/`; ❌ `host/layout/` parking |
| A62 | Foundation deps: flutter + google_fonts only; barrel exports paint/protocol — not PackLayoutHost |
| A57 historical | host/layout wipe remains ✅; A60 corrects where the runner lives (engine kit, not DS) |

| Still open | Detail |
|------------|--------|
| A50 | Fat kit wire (~7k) still not sync/FFI-only |

---

## Acceptance (validate + paint)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A63 | Law: host = schema validate + paint only; forbidden field mappers / schedule·feed·panel·tabs product runtimes | ✅ |
| 2 | R109-A64 | Deleted kit product surface (`pack_layout_host_wire`, list/feed/schedule/chrome hooks); thin `PackLayoutPainter` + opaque `packOpaqueRun` | ✅ |
| 3 | R109-A65 | Packs declare `nav.page.action` + `hubPaintPoster` / `hubWithLoad`; anime (+ peers) reference migration | ✅ |

---

## Acceptance (pack-owned search)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A66 | Delete `HostSearchEngine` / `host_search` capability — host never knows TMDB/addons | ✅ |
| 2 | R109-A67 | Home pack `_search.js` + opaque `action: search`; prelude may be comma-separated | ✅ |
| 3 | R109-A68 | `KitSearchScreen` / `openCatalogSearch` only `runPlugin(…, 'search')` + paint/open | ✅ |

---

## Acceptance (catalog slot paint)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A69 | Restore foundation catalog paint: `CinematicHero`, `ContinueSection`, `BecauseSection`, `ContinueWatchingCard`, `MoodSection` | ✅ |
| 2 | R109-A70 | `PackPaintTree` mounts hero / vertical_filters / mood / continue / because / ranked via `kit/slots/*` + shared `PackPaintArtifact` | ✅ |
| 3 | R109-A71 | Pack `hubItems` stamps `hubPaintPoster` when missing; home `hubPaintHero` + `hubWithLoad` on hero/popular/mood/because/genres | ✅ |
| 4 | R109-A72 | Asian Drama / Anime peers: `hubWithLoad` on hero/ranked/mood; layout_map lists mounted slots | ✅ |

---

## Acceptance (empty-shell chassis)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A77 | Law: app = empty chassis; foundation owns brand/nav/body paint; packs own product chrome | ✅ |
| 2 | R109-A78 | Delete host `KitChromeTopBar` / `ShellSearchBar`; strip `home*` / continue-watching / iptv product APIs from shell | ✅ |
| 3 | R109-A79 | Brand + focus/layout paint live in `forja_foundation` | 🔄 |
| 4 | R109-A80 | Opaque bus / VF registry under `shared/engine`; foundation empty-shell primitives usable without fat host scaffold | ✅ |
| 5 | R109-A81 | `lib/shell/` collapsed to chassis; zero hardcoded product tab ids in shell bus/TV focus | ✅ |

---

## Wave M notes (validate + paint law reset)

| Done | Detail |
|------|--------|
| A63 | `forja-pack-product-host.mdc` — validate+paint; ❌ KitListPaint / feed/schedule/panel/tabs host product |
| A64 | Kit folder = painter + paint_tree + opaque run; fat wire/list/feed/schedule deleted (A50 closed by deletion) |
| A65 | Hub manifests `nav.page.action`; SDK + `_kit.js` paint helpers; rails wrap `hubWithLoad`; anime/asian_drama paint metas |
| A69–A72 | Catalog slot paint: DS hero/continue/because/mood kept; host `paint_artifact` + `kit/slots/*` (no mega paint_slots) |

| Still open | Detail |
|------------|--------|
| Chrome | `kit.topBar` / `kit.categoryBar` **mount** in `PackPaintTree`; product chrome **behavior** (selection→feed, dynamic cats, portals/search/refresh, list panel) still incomplete — [issue 279](../issues/279-[open]-hub-catalog-design-regressions-thin-painter.md) A11 · pack roots [281](../issues/281-[open]-pack-hub-design-parity-all-hubs.md) |


| Done (pack parity) | Detail |
|--------------------|--------|
| IPTV | `hubWithLoad(…, 'feed')` on list; `hubPaintPoster` on live/VOD/setup rows; paint helpers in `_prelude.js` (v1.5.5) |
| Live Sports | `hubWithLoad(…, 'feed')` on schedule list; `hubPaintEvent` on shaped rows; paint helpers in `_prelude.js` (v1.0.29) |
| Search | Home + anime/asian_drama/arabic/aflem/cartoon/kids/shahid each ship `_search.js`; host has no product search engine |

---

## Acceptance (live channel-guide paint)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A73 | Channel-guide / EPG / search / stats paint in `forja_foundation/widgets/guide/` (props + callbacks only; no `package:forja`) | ✅ |
| 2 | R109-A74 | Host thin adapters under `player/live/channel_guide/` (factories, `GuideEpgCache`, MediaKit/Exo stats); delete `engine/portals/channel_guide/` | ✅ |
| 3 | R109-A75 | Delete `player/iptv/` product tree; live decode under `player/live/`; dead catalog-recs IPTV path removed from details hooks | ✅ |
| 4 | R109-A76 | Guide chrome / focus paint tokens in foundation (`GuideChromeStyle`); host `tv_focus` renamed off `Iptv*` action widgets | ✅ |

---

## Wave N notes (live channel-guide dissolve)

| Done | Detail |
|------|--------|
| A73 | Foundation: `ChannelGuidePanel`, `ChannelSearchOverlay`, `GuideEpgCard`, `PlayerStatsList`, hold-accel / letter-jump paint helpers |
| A74 | Host: `player/live/channel_guide/*` wires portal client + shell TV into callbacks; portals barrel no longer exports guide UI |
| A75 | `shared/player/iptv/` gone; `loadCatalogRecs` / `_iptvRecHits` deleted; `LivePlaySource` rename on player path |
| A76 | `GuideChromeStyle` + `LiveTvScrollbar` in DS; host focus actions use `FocusIconAction` names |
| A50 | `engine/portals` Dart types/files renamed off `Iptv*` → `Portal*` (opaque portal engine); vault string keys (`iptv.portals`, …) unchanged; guide typedefs dropped for foundation names |

| Still open | Detail |
|------------|--------|
| A13 / A17 / A30 / A32 | Prior 🔄 debt unchanged |

---

## Acceptance (guide out of live player)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A82 | Portal guide adapters under `engine/portals/guide/` (factories, `GuideEpgCache`, `PortalGuideWire`, floating EPG); player mounts foundation widgets directly | ✅ |
| 2 | R109-A83 | Delete `player/live/channel_guide/`; MediaKit/Exo stats probe host at `player/live/player_stats_panel.dart` | ✅ |

---

## Acceptance (pack-owned portal forms)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A84 | Foundation `FormFieldsSpec` / `showFormFieldsDialog` — generic title/fields/submit only | ✅ |
| 2 | R109-A85 | IPTV pack `listPortals.layout` declares Add / Import / Edit forms + `importPortal`; empty feed copy points at Portals | ✅ |
| 3 | R109-A86 | Host portals chrome paints pack forms (no hardcoded Edit/Add dialog strings/fields); submit → opaque `runPlugin` | ✅ |

---

## Acceptance (runtime action wires)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-A87 | Split flat `runtime/chrome/` → `runtime/actions/{portals,category_bar,event_search,schedule}/` + `runtime/kit/hosts/` | ✅ |

---

## Wave N+1 notes (guide out of live player)

| Done | Detail |
|------|--------|
| A82 | `engine/portals/guide/*` owns portal→paint mapping; `pt_player_ui` wires foundation `ChannelGuidePanel` / `ChannelSearchOverlay` with shell TV + portal callbacks |
| A83 | `player/live/channel_guide/` removed; stats probe stays next to live decode |

| Still open | Detail |
|------------|--------|
| Pack in-player guide open | Hub pack should declare guide open payload; host open path does not yet pass `channelGuide` into `PtPlayerScreen` |
