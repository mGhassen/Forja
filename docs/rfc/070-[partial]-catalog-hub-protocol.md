# RFC-070: Catalog hub protocol — shell tabs from `kind: catalog` plugins

**Status:** partial  
**Depends on:** [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md) · [RFC-069](fixed/069-[fixed]-official-plugins-split.md)  
**Area:** `shared/catalog/`, `EngineService`, `PluginRegistry`, `shell/nav_config.dart`, `plugins/hubs/`

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** components · **14 / 15** acceptance (protocol) · **12 / 12** acceptance (hub parity) · **4 / 4** acceptance (host enrich) · **1 / 1** acceptance (required packs) · **4 / 4** acceptance (shared cache) |
| **Current slice** | Shared cache restored (splash rail warm + TMDB match LRU); A15 manual QA still open |

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

## Acceptance (host enrich slice)

Pack-owned enrichment — host exposes reusable match APIs; plugins compose (AniList+TMDB, KissKH+TMDB, …). No CatalogShell `if (tabId == anime)` hardcode.

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R70-A28 | `ctx.host.tmdb.match({ title, year, type })` on EngineJS + flutter_js invokers | ✅ |
| 2 | R70-A29 | Shared kit helpers `hubTmdbMatch` / `hubEnrichTmdb` / `hubApplyTmdbHit` | ✅ |
| 3 | R70-A30 | Anime spotlight rail enriches via kit/host (CatalogShell anime TMDB hardcode removed) | ✅ |
| 4 | R70-A31 | Asian Drama spotlight rail enriches via kit/host (backdrop + synopsis/rating when KissKH omits them) | ✅ |

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
| 3 | R70-A35 | Details TMDB enrich (Asian Drama / Anime) process-cached via `HubTmdbEnrichCache` — survives Riverpod `autoDispose` leave/reopen | ✅ |
| 4 | R70-A36 | Hub hero View details uses pack open (`onDetails`) for anime/drama — TMDB enrich must not set `movie` (null `onOpenDetails` was a silent no-op) | ✅ |

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

### Host enrich (R70-A28+)

Catalog plugins may call shared host capabilities while composing metas:

```js
ctx.host.tmdb.match({ title: 'One Piece', year: 1999, type: 'tv' })
// → { id, mediaType, name, year, poster, backdrop } | null
```

Kit helpers (`hubTmdbMatch`, `hubEnrichTmdb`) prefer `ctx.host.tmdb.match` and fall back to `ctx.fetch` + injected `config.apiKey`. Packs own which rails enrich (AniList + KissKH spotlight) — CatalogShell only renders `meta`. Match hits may include `overview` / `rating`; `hubApplyTmdbHit` fills empty pack synopsis/score only. Rust `tmdb::match_json` keeps a process-lifetime match cache (R70-A34). Splash warms layout + first-paint rails into `CatalogCache` (R70-A33) — BootCache replacement.

### Related

- [RFC-066](fixed/066-[fixed]-hub-catalog-top-bar.md) — hub chrome the search slice reuses
- [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) — overlay that feeds hub config
- [RFC-064](064-[open]-rust-quickjs-engine-runtime.md) — Rust EngineJS invoker (R70-A12)
