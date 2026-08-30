# RFC-070: Catalog hub protocol — shell tabs from `kind: catalog` plugins

**Status:** partial  
**Depends on:** [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md) · [RFC-069](fixed/069-[fixed]-official-plugins-split.md)  
**Area:** `shared/catalog/`, `EngineService`, `PluginRegistry`, `shell/nav_config.dart`, `plugins/hubs/`

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** components · **14 / 15** acceptance (protocol) · **12 / 12** acceptance (hub parity) · **1 / 1** acceptance (hub contribution) · **4 / 4** acceptance (host enrich) · **5 / 5** acceptance (enrich companion) · **1 / 1** acceptance (required packs) · **6 / 6** acceptance (shared cache) · **2 / 2** acceptance (host assets) · **7 / 7** acceptance (Arabic sources / open) |
| **Current slice** | `shared/catalog/kit/` widget library; A15 manual QA still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-C01 | `shared/catalog/protocol.dart` — envelope, error codes, meta item, filter AST, layout validation, nav spec | ✅ |
| 2 | R70-C02 | `shared/catalog/cache.dart` — keyed cache with etag / maxAge / SWR + pack-version wipe | ✅ |
| 3 | R70-C03 | `shared/catalog/runtime.dart` — `CatalogRuntime.run` (cache read, background revalidate, `notModified`) | ✅ |
| 4 | R70-C04 | `shared/catalog/{filter,plugin_nav,deeplink}.dart` | ✅ |
| 5 | R70-C05 | `EnginePlugin` `protocol` / `kit` / `capabilities` / `nav` + `isHubCatalog` / `needsScript` | ✅ |
| 6 | R70-C06 | `EngineService.runCatalog` + `listHubCatalogPlugins` (Rust EngineJS, flutter_js fallback) | ✅ |
| 7 | R70-C07 | `PluginRegistry` `hubs` slot — `FORJA_HQ_HUBS_MANIFEST_URL`, `forjahq-hubs` pack id | ✅ |
| 8 | R70-C08 | `CatalogShell` + `plugins/hubs` pack (`_kit.js`, tmdb, anilist, kisskh, arabic) | ✅ |
| 9 | R70-C09 | `ForjaHostAssets` — `forja://asset/{id}` catalog → Flutter paths; packs never use `assets/` | ✅ |
| 10 | R70-C10 | `shared/catalog/kit/` — rows, cards, host widgets, chrome; [CatalogShell](shell/catalog_shell.dart) composes layout only | ✅ |

---

## Acceptance (protocol slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A01 | Plugin returns `[envelope]`; host reads it from a list or a bare map | ✅ |
| 2 | R70-A02 | Wire error codes parse; `AUTH_REQUIRED` and `UNSUPPORTED_KIT` surface to the shell | ✅ |
| 3 | R70-A03 | `validateLayoutData` rejects missing pages / widgets / widget type | ✅ |
| 4 | R70-A04 | Cache key stable across param order; auth subject and params scope it | ✅ |
| 5 | R70-A05 | Fresh hit skips the plugin; stale-in-SWR serves cache and revalidates in background | ✅ |
| 6 | R70-A06 | Hubs pack version change wipes the catalog cache | ✅ |
| 7 | R70-A07 | Filter AST merges chrome selections; empty selections add no filter | ✅ |
| 8 | R70-A08 | `forja://catalog/{pluginId}/{action}?id=` parses and round-trips | ✅ |
| 9 | R70-A09 | `kind: catalog` plugins install scripts, stay out of Sources chips (`isExtractable == false`) | ✅ |
| 10 | R70-A10 | Home / Anime / Asian Drama / Arabic tabs render from the hubs pack | ✅ |
| 11 | R70-A11 | `FORJA_HQ_HUBS_MANIFEST_URL` becomes a required pack (engine refuses to boot without it) | ✅ |
| 12 | R70-A12 | Rust EngineJS invoker forwards `params` / `auth` / `cache` as first-class `ctx` fields | ✅ |
| 13 | R70-A13 | Shell nav is built from `navSpecs()` instead of the static `navDestinations` map | ✅ |
| 14 | R70-A14 | TMDB hub key comes from the app (no manual `apiKey` in pack config) | ✅ |
| 15 | R70-A15 | Manual QA: four hub tabs on desktop + Android TV D-pad | ⬜ |

---

## Acceptance (hub parity slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A16 | `hero` widget renders the shared cinematic hero (not a poster rail) | ✅ |
| 2 | R70-A17 | `host.continue` renders host-owned Continue Watching | ✅ |
| 3 | R70-A18 | Hub top bar / search (`HubCatalogTopBar`, `hub_search_page`) wired to the `search` action | ✅ |
| 4 | R70-A19 | `details` action feeds the details screens instead of a synthesized card | ✅ |
| 5 | R70-A20 | Legacy `HomeScreen` / `AnimeScreen` / `AsianDramaScreen` / `ArabicScreen` retired | ✅ |
| 6 | R70-A21 | Hub top-bar Films / Series / Categories feed `filter` into `rail` (CatalogShell + hubs pack) | ✅ |
| 7 | R70-A22 | One official pack per hub page — `forjahq-home` / `forjahq-anime` / `forjahq-asian-drama` (+ 3 dart-defines) | ✅ |
| 8 | R70-A23 | Arabic is its own pack (`forjahq-arabic` / `FORJA_HQ_ARABIC_MANIFEST_URL`) — not nested under Home | ✅ |
| 9 | R70-A24 | Settings → Forja lists `kind: catalog` under **Hubs** (not Live **Catalog** / Movie & TV) | ✅ |
| 10 | R70-A25 | Asian Drama hub plugin id is `kisskh-hub` — no collision with providers extract `kisskh` | ✅ |
| 11 | R70-A26 | Hub pack layouts + CatalogShell match pre-cutover row order / mood circles / hero bleed / Asian landscape + TMDB Popular (host Because/Trakt/genre rows still open) | ✅ |
| 12 | R70-A27 | Every hub with `nav` registers Settings → Features; plugin enable (Sources) is independent of Features show/hide | ✅ |

---

## Acceptance (hub contribution — enabled only)

Disabled hubs must leave Features / rail (supersedes the “keep Features row while plugin off” reading of A27).

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A41 | Only enabled pack+plugin hubs contribute to `PluginNavRegistry` / Features / rail; disable removes the row | ✅ |

---

## Acceptance (host enrich slice)

Pack-owned enrichment — host exposes reusable match APIs; plugins compose (AniList+TMDB, KissKH+TMDB, …). No CatalogShell `if (tabId == anime)` hardcode.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A28 | `ctx.host.tmdb.match({ title, year, type })` on EngineJS + flutter_js invokers | ✅ |
| 2 | R70-A29 | Shared kit helpers `hubTmdbMatch` / `hubEnrichTmdb` / `hubApplyTmdbHit` | ✅ |
| 3 | R70-A30 | Anime spotlight rail enriches via kit/host (CatalogShell anime TMDB hardcode removed) | ✅ |
| 4 | R70-A31 | Asian Drama spotlight rail enriches via kit/host (backdrop + synopsis/rating when KissKH omits them) | ✅ |

---

## Acceptance (enrich companion)

Source hub JS stays data-only. Pack declares `"enrich": "<pluginId>"`; host pipes `rail` / `details` through that companion’s `enrich` action.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A42 | `EnginePlugin.enrich` + `CatalogRuntime` pipes `rail`/`details` items/meta through companion `enrich` before cache | ✅ |
| 2 | R70-A43 | Asian Drama: `kisskh.js` standalone; `enrich_tmdb.js` + manifest `enrich: enrich-tmdb` (spotlight + details meta) | ✅ |
| 3 | R70-A44 | Anime: `anilist.js` standalone; `enrich_tmdb.js` + manifest `enrich: anime-enrich-tmdb` (spotlight + details meta) | ✅ |
| 4 | R70-A49 | `hubEnrichTmdb` prefers `meta.ids.tmdb` (fetch by id, movie↔tv fallback) before title search — same as details | ✅ |
| 5 | R70-A50 | Hub cinematic hero client enrich uses `KissKhTmdbMatch` + dual-type details fetch (not first-with-backdrop) | ✅ |

---

## Acceptance (required packs — in-scope)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A32 | Required official packs = 6 (Providers/Live/Catalog/Home/Anime/Asian Drama); Arabic dart-define optional / out of product scope | ✅ |

---

## Acceptance (shared cache — BootCache parity)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A33 | Splash prefetches default hub layout + first-paint rails into `CatalogCache` (Home: spotlight/featured/popular/new_releases; Anime/Asian Drama: hero + bleed) | ✅ |
| 2 | R70-A34 | `tmdb::match_json` process cache (30m TTL, 256 cap) so hub enrich reuses TMDB match hits across revalidate / hubs | ✅ |
| 3 | R70-A35 | Details TMDB enrich keyed by KissKH id via `HubTmdbEnrichCache` — reopen skips rematch + paint-gate animation (`instant`) | ✅ |
| 4 | R70-A36 | Hub hero View details uses pack open (`onDetails`) for anime/drama — TMDB enrich must not set `movie` (null `onOpenDetails` was a silent no-op) | ✅ |
| 5 | R70-A37 | `AnimeService` process-caches `getDetails` / `getSeasons` / TMDB match+rich; AniList `_query` backs off on HTTP 429 | ✅ |
| 6 | R70-A38 | CatalogShell memoizes rail/hero Futures by chrome+mood; sections keep last paint — rebuild / tab return does not shimmer-reload | ✅ |

---

## Acceptance (host assets)

Packs reference host icons by Forja URI only. Real Flutter paths stay in the app.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A39 | `ForjaHostAssets` maps `forja://asset/nav/*` → bundled nav PNGs; unknown / raw `assets/` resolve to null | ✅ |
| 2 | R70-A40 | Official hub manifests use `forja://asset/nav/…`; `PluginNavRegistry.refresh` resolves via catalog (no `startsWith('assets/')`) | ✅ |

---

## Acceptance (Arabic sources)

Optional Arabic pack — browse/search/details/stream from Larozaa + DimaToon + Brstej; open via pack-declared `meta.open.surface` (host never names scrapers).

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A45 | `arabic.js` rails: Larozaa categories + Brstej latest (no longer empty stub) | ✅ |
| 2 | R70-A46 | Arabic hub `search` merges Larozaa + DimaToon + Brstej | ✅ |
| 3 | R70-A47 | Hub metas declare `open: { surface, id, … }`; host `openCatalogMetaItem` switches only on surface (no pack/scraper id keys) | ✅ |
| 4 | R70-A48 | Hub open uses shell meta immediately (no await pack `details`/enrich); same plugin+id re-entry ignored until route pops — no double details / 429 stall | ✅ |
| 5 | R70-A51 | Arabic hub `details` returns `meta.videos` (opaque ids); host details UI loads via `CatalogRuntime` only — no host scrapers | ✅ |
| 6 | R70-A52 | Arabic providers extract direct HLS/MP4 in JS (Larozaa/Brstej unpack embed pages); host plays like Videasy — no `arabic_embed` hop | ✅ |
| 7 | R70-A53 | Host `ArabicService` / scraper string switches deleted; Arabic pack owns site HTML | ✅ |

---

## Manual QA (A15)

Desktop + Android TV D-pad — mark A15 ✅ only after this list is run:

| Check | Desktop | ATV |
|-------|---------|-----|
| Home / Anime / Asian Drama / Arabic open via CatalogShell | ⬜ | ⬜ |
| Hero + Continue Watching + rails paint | ⬜ | ⬜ |
| Films / Series / Categories refetch rails (Home / Anime / Asian Drama) | ⬜ | ⬜ |
| Hub Search opens pack `search` | ⬜ | ⬜ |
| Card → details (TMDB / AniList / KissKH) | ⬜ | ⬜ |
| D-pad: menu → hero → rails; text fields browse-only | — | ⬜ |

---

## Summary

Shell catalog tabs stop being hardcoded Flutter screens with baked-in services and become **plugin-served hubs**. A `kind: catalog` plugin answers a small protocol — `layout`, `rail`, `search`, `details`, `filters` — and the host renders it.

### Wire shape

```json
[{ "ok": true, "kit": 1, "protocol": 1, "action": "rail",
   "cache": { "etag": "…", "maxAge": 600, "swr": 3600 },
   "data": { "items": [ { "id": "anilist:21", "type": "anime", "name": "ONE PIECE" } ] } }]
```

Plugins resolve to a **one-element array** because both engine paths (`flutter_js` and Rust EngineJS) only carry a JSON array back to Dart.

### Request transport

`ctx.action`, `ctx.params`, `ctx.auth`, `ctx.cache`, `ctx.kit`, and `ctx.protocol`
are first-class fields on both the Rust EngineJS and flutter_js invokers
(R70-A12). `_kit.js` prefers those fields and still accepts a legacy
`ctx.config.__request` blob for older hosts.

### Required packs

Six official dart-defines are required — `requiredOfficialPackCount == 6`
(providers, live, catalog, home, anime, asian_drama). Arabic
(`FORJA_HQ_ARABIC_MANIFEST_URL`) is optional / out of product scope.
Unset any of
`FORJA_HQ_HOME_MANIFEST_URL` / `FORJA_HQ_ANIME_MANIFEST_URL` /
`FORJA_HQ_ASIAN_DRAMA_MANIFEST_URL`
fails engine boot the same way as a missing providers URL. The legacy combined
`forjahq-hubs` pack is treated as a shadow and replaced. Arabic nav stays
`defaultEnabled: false` until sources ship.

### Goals

- One plugin contract for every catalog surface — no per-tab Dart service
- Host owns caching, freshness, error UX, navigation; plugin owns fetch + shape
- `nav` in the manifest declares which shell tab a plugin serves

### Contracts

| Action | `params` | `data` |
|---|---|---|
| `layout` | `page` | `pages.{page}.widgets[]` |
| `rail` | `rail`, `filter`, `sort`, `page`, `limit`, `cursor` | `items[]`, `nextCursor` |
| `search` | `query`, `page`, `limit` | `items[]` |
| `details` | `id` | `meta` |
| `filters` | — | `fields[]` |

Widget types: `hero`, `rail`, `ranked`, `mood`, `host.continue`, `host.popular_asian`, …

### Host widget kit (R70-C10)

Dart UI for hub plugins lives under `shared/catalog/kit/` — not in feature browse screens:

| Folder | Role |
|--------|------|
| `kit/cards/` | `HomeMovieCard`, `HubPosterCard` (+ My List pin) |
| `kit/rows/` | `HomeMovieSection`, `HubCatalogSection` (horizontal / numbered / vertical) |
| `kit/home/` | Home-only sections: mood, continue, because |
| `kit/host/` | `host.*` layout slots: continue router, trakt, genre rows, popular Asian, … |
| `kit/chrome/` | Vertical filters, chrome filter AST bridge, hub search page |
| `kit/meta/` | `CatalogMetaItem` → `Movie` for TMDB home rows |
| `shell/` | `CatalogShell` composition + open/search only |

Legacy import paths (`features/home/widgets/*`, `shared/widgets/hub/*`) re-export the kit for gradual migration.

### Host enrich (R70-A28+)

Catalog plugins may call shared host capabilities while composing metas:

```js
ctx.host.tmdb.match({ title: 'One Piece', year: 1999, type: 'tv' })
// → { id, mediaType, name, year, poster, backdrop } | null
```

Kit helpers (`hubTmdbMatch`, `hubEnrichTmdb`, `hubTmdbById`) prefer `meta.ids.tmdb` (details fetch, movie↔tv fallback) before title search via `ctx.host.tmdb.match`, and fall back to `ctx.fetch` + injected `config.apiKey`. Source plugins may call kit enrich inline **or** declare a companion via `"enrich": "<pluginId>"` — host runs `action: enrich` after `rail`/`details` and caches the merged payload (R70-A42–A44, R70-A49–A50: Asian Drama `enrich-tmdb`, Anime `anime-enrich-tmdb`; hub hero client uses the same scored matcher as details). CatalogShell only renders `meta`. Match hits may include `overview` / `rating`; `hubApplyTmdbHit` fills empty pack synopsis/score only. Rust `tmdb::match_json` keeps a process-lifetime match cache (R70-A34). Splash warms layout + first-paint rails into `CatalogCache` (R70-A33) — BootCache replacement.

### Host assets (R70-A39+)

Hub `nav.icon` must be a Forja host asset URI, not a Flutter path:

```json
"icon": "forja://asset/nav/asian-drama"
```

`ForjaHostAssets.catalog` is the allow-list (`nav/home`, `nav/anime`, `nav/asian-drama`, `nav/search`, `nav/live-matches`, `nav/iptv`, …). The host resolves to `assets/images/nav/…` for `Image.asset`. Raw `assets/…` from a pack is ignored.

### Play contract (browse vs provider JS)

Hub packs (`kind: catalog`, `runCatalog`) own **browse only** — rails, search, filters, details metadata, `open.surface`. They never extract stream URLs and never appear in Sources chips (`isExtractable == false`).

VOD play uses **provider JS** (`plugins/providers/*.js`, `runPlugin` / `runPluginIsolated`) plus the shared Sources panel (Torrents / Stremio / Nuvio / Forja):

| User action | Host path |
|-------------|-----------|
| Green Play (movie / TV / anime / drama / Arabic hub) | `runEngineAutoPlay` → races enabled provider plugins |
| Sources (link) | `PlayerSourcesPanel` → same panel as TMDB details |
| In-player next episode (engine session) | `switchEpisodeViaEngineAutoPlay` |

Legacy Dart/Rust webstreaming sniff, dedicated anime/drama players, and built-in `StreamProviders` catalog are removed for VOD. ID injection for hub play:

- `anilistId` / `malId` on anime green Play and Sources
- `config.dramaId` / `config.episodeId` for provider `kisskh` (from hub details KissKH ids)
- `config.videoId` for Arabic providers (`larozaa`, `dimatoon`, `brstej`)

Shared kit: [`hub_play_context.dart`](../../apps/forja/lib/shared/playback/hub_play_context.dart), [`hub_details_play.dart`](../../apps/forja/lib/shared/catalog/kit/details/hub_details_play.dart).

### Related

- [RFC-066](fixed/066-[fixed]-hub-catalog-top-bar.md) — hub chrome the search slice reuses
- [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) — overlay that feeds hub config
- [RFC-064](064-[open]-rust-quickjs-engine-runtime.md) — Rust EngineJS invoker (R70-A12)
