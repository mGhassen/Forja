# RFC-109: Forja pack-product host

**Status:** open  
**Depends on:** [RFC-081](fixed/081-[fixed]-host-only-platform-nav-defaults.md) · [RFC-087](fixed/087-[fixed]-live-sports-pack-only.md) · [RFC-088](fixed/088-[fixed]-my-list-pack-only.md) · [RFC-106](106-[open]-forja-foundation-design-system-package.md) · [issue 271](../issues/271-[open]-catalog-body-evacuate-foundation.md)  
**Area:** host architecture / packs / foundation

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 7** components · **8 / 8** acceptance (law/docs) · **8 / 10** acceptance (code) · **2 / 10** 🔄 interim debt |
| **Current slice** | Gates landed — hub/lists/live/features/iptv gone; shell has no kit_; interim portals_ui + feeds aggregate + ctx.host aliases remain |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R109-C01 | Law + cursor rule `forja-pack-product-host.mdc` | ✅ |
| 2 | R109-C02 | Widgets only in `forja_foundation`; `apps/forja/shared/shell` = frame | 🔄 |
| 3 | R109-C03 | Dissolve `shared/engine/{hub,lists,live}` → generic `runtime/cache/store/portals/unlock` | ✅ |
| 4 | R109-C04 | `features/iptv` product → pack + `engine/portals` | ✅ |
| 5 | R109-C05 | Generic `ctx.host` (`cache`/`store`/`portals`/`plugin`/`playback`) — no `liveFeed`/`myList`/product `iptv` | 🔄 |
| 6 | R109-C06 | Packs own live aggregate, list UX, IPTV browse | 🔄 |
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
| 7 | R109-A15 | No `ctx.host.liveFeed` / product `myList` / product `iptv` namespaces | 🔄 |
| 8 | R109-A16 | live_sports pack owns schedule aggregate (no host liveFeed) | 🔄 |
| 9 | R109-A17 | Playback has no asian_drama/anime/kisskh behavioral branches outside runPlugin boundary | 🔄 |
| 10 | R109-A18 | Feature docs: IPTV / Live / My List = pack install | ✅ |

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

### Target trees

```text
apps/forja/lib/shared/engine/
  runtime/  packs/  cache/  store/  feeds/  portals/  unlock/
apps/forja/lib/shared/shell/   # frame only — NO kit_
apps/forja/lib/features/       # account + settings only
```

### Generic `ctx.host`

| API | Replaces |
|-----|----------|
| `cache.*` | MetaCache |
| `store.*` | bookmarks / list_follow |
| `portals.*` | features/iptv data + searchChannels |
| `plugin.run` | ad-hoc runners |
| `playback.open` | iptv/live play entry |
| **DELETE** | `liveFeed`, `myList`, product `iptv` |

### Grep gates (`apps/forja/lib`)

Forbidden: `engine/hub`, `engine/lists`, `engine/live`, `features/iptv`, `MetaCache`, `KitLiveBoot`, `liveFeed`, `kit_` under `shared/shell`.

### Related

- [forja-pack-product-host.mdc](../../.cursor/rules/forja-pack-product-host.mdc)
- [RFC-094](094-[partial]-community-pack-url-scoped-ids.md) · [RFC-099](099-[open]-live-unlock-pack-modules.md) · [issue 271](../issues/271-[open]-catalog-body-evacuate-foundation.md)

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
| `KitLiveBoot` deleted | Thin `LiveSurfaceOpen.ensureRegistered` — panel + surface + top-bar only |
| `MetaFeedListSource` deleted | Packs use `PluginHubFeedListSource` → MetaRuntime `feed` (+ chrome catalog/horizon params) |
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
| A16 | Host still has `liveFeed` alias + host-side aggregate; pack calls `feed.load` |
| A17 | Playback scent strip partial (kisskh sniff / anilist score scope removed; SourceDomain + settings lists remain) |
| A11 | ✅ `hub` / `lists` / `live` / `features/iptv` dirs gone |
| A15 | Temporary aliases: `liveFeed`→`feed`, `bookmarks`→`store`, `iptv`→`portals` |

---

## Wave 3 notes (lists + live dissolve)

| Done | Detail |
|------|--------|
| `engine/lists/` gone | Persist/follow → `engine/store/` (`list_follow*`, `list_open_prefs`, `list_open_binding`, `list_open_title_rank`) |
| List UI | Picker / bind sheet / flow + Riverpod providers → `shared/host/lists_ui/` |
| `engine/live/` gone | Aggregate / merge / resolve / match / stremio / capabilities → `engine/feeds/` (kept `live_*` filenames) |
| `kit_schedule_window` | → `shared/host/layout/kit/` (with sheet) |
| `embed_webview_proxy` | Deleted (test-only; no production callers) |

| Still open | Detail |
|------------|--------|
| A13 | `ListFollow` still wraps bookmarks; `EngineStore` is the generic surface — migrate callers |
| A16 | Host-side `feeds/` aggregate remains until pack owns schedule load |
| C03 | `feeds/` is the interim generic name (not product `live/`) |

---

## Wave 5+6 notes (generic ctx.host + scent)

| Done | Detail |
|------|--------|
| `ctx.host.cache` | `get` / `set` / `invalidate` → `EngineCache` |
| `ctx.host.store` | `list` / `upsert` / `remove` → `EngineStore` (`bookmarks.list` aliases `store.list`) |
| `ctx.host.portals.searchChannels` | Wires existing `IptvChannelSearch` (`iptv` alias kept) |
| `ctx.host.feed.load` | Same aggregate as former `liveFeed.load` (deprecated alias kept) |
| Packs | `live_sports` → `feed.load` + `portals.searchChannels`; `my_list` → `store.list` |
| Playback | Stripped kisskh provider sniff / invent-referer; anime score uses opaque tv scope |
| Feature docs + changelog | IPTV / Live / My List = pack install |

---

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
