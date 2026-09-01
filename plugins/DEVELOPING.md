# Developing Forja plugins

Community guide for building **EngineJS packs** — JavaScript plugins the Forja app installs, caches, and runs at runtime.

The Flutter app is a **host**. It does not ship your scripts. Users install packs by manifest URL (**Settings → Sources → Forja → Add plugin**). Official reference packs live in this folder; fork them or publish your own CDN/GitHub raw URLs.

**See also:** [README.md](README.md) (official pack inventory) · [docs/rfc/070-[partial]-catalog-hub-protocol.md](../docs/rfc/070-[partial]-catalog-hub-protocol.md) (hub protocol spec)

---

## Mental model

```
manifest.json  →  pack metadata + plugin entries
     ↓
entry.js       →  export function extract(ctx) { … }
     ↓
Forja host     →  loads script, calls extract, maps result to UI / player
```

| Pack tree | Plugin `kind` | Role |
|-----------|---------------|------|
| `providers/` | `http` (default) | VOD stream extract — movie / tv / anime / drama |
| `providers/hops/` | `hop` | Follow file-host redirects to a playable URL |
| `live/` | `http` + `live_sport` type | Live Matches schedule + stream resolve |
| `hubs/` | `catalog` | Shell catalog tabs (Home, Anime, …) |
| `iptv/` | `catalog` | Feature packs without shell tabs (IPTV VOD details) |

Hub plugins **browse** catalogs. Provider plugins **extract streams**. The host keeps those layers separate — hub packs never appear in the Sources chip list.

---

## Quick start

### 1. Create a minimal pack

```
my-pack/
  manifest.json
  hello.js
```

**manifest.json**

```json
{
  "schema": 1,
  "id": "my-community-pack",
  "name": "My Community Pack",
  "version": "1.0.0",
  "plugins": [
    {
      "id": "hello-vod",
      "name": "Hello VOD",
      "entry": "hello.js",
      "types": ["movie", "tv"],
      "kind": "http"
    }
  ]
}
```

**hello.js**

```javascript
function extract(ctx) {
  // Return [] when you have no streams for this title.
  return Promise.resolve([]);
}
```

### 2. Install locally (desktop)

**Settings → Sources → Forja → Add plugin** — paste an absolute path:

```
/Users/you/Forja/plugins/providers/manifest.json
```

`file://` URLs work on desktop dev builds. On mobile, host the manifest over HTTPS (GitHub raw, your CDN, etc.).

### 3. Bump `version` to ship updates

When remote `version` is newer than the cached pack, Forja auto-refreshes on boot or when the user taps **Reload** on that pack.

---

## Pack manifest

Top-level fields:

| Field | Required | Description |
|-------|----------|-------------|
| `schema` | yes | Always `1` today |
| `id` | yes | Stable pack id (e.g. `forjahq-providers`). Used for prefs + collision checks |
| `name` | yes | Display name in Settings |
| `version` | yes | Semver string (`major.minor.patch`) |
| `plugins` | yes | Array of plugin objects |
| `enabled` | no | Pack master switch (default `true`) |

Each **plugin** object:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique **across all installed packs** — install refuses duplicates |
| `name` | yes | Display name |
| `entry` | yes | JS filename relative to manifest directory |
| `kind` | no | `http` (default), `hop`, `catalog`, `host` |
| `types` | no | Domain tags — see [Plugin types](#plugin-types) |
| `enabled` | no | Per-plugin toggle (default `true`) |
| `config` | no | Opaque JSON merged into `ctx.config` at runtime |
| `prelude` | no | Shared JS file prepended before `entry` (e.g. `_kit.js`) |
| `capabilities` | no | Feature flags (`catalog`, `resolve`, `nav`, `search`, …) |
| `nav` | no | Shell tab contribution for `kind: catalog` |
| `enrich` | no | Companion plugin id for post-rail/details enrich |
| `hosts` | no | Hostname suffixes for `kind: hop` |
| `protocol` / `kit` | catalog | Must match host — currently **`1`** / **`1`** |
| `ctxConfigMap` | no | Maps extract ctx keys → config keys at VOD extract time |

Script paths resolve relative to the manifest URL. Install is **transactional**: if any `entry` or `prelude` file fails to fetch, nothing from that install attempt is written.

---

## Plugin types

`types[]` controls where the plugin appears in Settings and which extract context it receives.

| Type | Typical use |
|------|-------------|
| `movie`, `tv` | Movie & TV stream providers |
| `anime` | Anime providers |
| `drama` | Asian drama providers |
| `live_sport` | Live Matches schedule + resolve |
| `catalog` | Legacy live schedule (prefer `live_sport` + capabilities) |
| `iptv` | IPTV feature plugins (no shell tab) |

Use **your own** type tokens for niche packs — the host reads them generically. Do not assume official ids (`kisskh`, `anilist`, …) exist on every user's device.

---

## VOD extract plugins (`kind: http`)

The workhorse. Implement **`extract(ctx)`** returning a **Promise** (or sync array) of stream objects.

### Extract context

The host passes title/episode ids and merged config:

```javascript
// ctx fields (VOD)
ctx.tmdbId      // string
ctx.imdbId      // string
ctx.malId       // number | string (anime)
ctx.anilistId   // number | string (anime)
ctx.type        // 'movie' | 'tv'
ctx.season      // number (tv)
ctx.episode     // number (tv)
ctx.title       // string
ctx.year        // string
ctx.url         // string — direct URL when resolving a hop/link
ctx.config      // manifest config + optional cloud overlay
ctx.fetch(url, opts)  // HTTP — same-origin rules as browser fetch in engine
ctx.hop(url)    // delegate to matching hop plugin
ctx.log(msg) / ctx.error(msg)
ctx.crypto.*    // STREAMCRYPTO decrypt, encode/decode helpers — see official packs
```

Cloud **provider runtime config** can overlay `config` without reinstalling the pack (API hosts, mirror lists, keys).

### Stream objects

Return an array of maps. Empty array = no streams (not an error).

```javascript
{
  url: 'https://cdn.example/playlist.m3u8',  // required
  name: 'Mirror A',           // server label (optional)
  title: '1080p HLS',         // row subtitle (optional)
  quality: '1080p',           // 4K | 1080p | 720p | … (optional)
  language: 'English',        // optional
  audio: 'AAC',               // optional
  headers: {                  // optional — Referer, User-Agent, Origin
    'User-Agent': '…',
    Referer: 'https://embed.example/',
  },
  subtitles: [ … ],           // optional — same shape Stremio uses
}
```

The host HTTP-probes URLs before playback. Prefer stable CDN links and correct Referer/Origin headers.

### Minimal provider

See [`providers/vidlink.js`](providers/vidlink.js) for a full TMDB-id API resolver, or [`providers/hops/filemoon.js`](providers/hops/filemoon.js) for hop-style extract.

---

## Hop plugins (`kind: hop`)

File-host unwrap plugins. Registered by **`hosts`** (hostname suffix match).

```javascript
// manifest
{
  "id": "filemoon-hop",
  "kind": "hop",
  "entry": "hops/filemoon.js",
  "hosts": ["filemoon.sx", "filemoon.to"]
}
```

When a provider calls `ctx.hop(url)`, the host picks the hop plugin whose `hosts` suffix-matches the URL hostname.

Hop `extract(ctx)` receives **`ctx.url`** (the embed page) and returns the same stream array shape as VOD plugins.

---

## Live sport plugins

Live Matches plugins use **`types: ["live_sport"]`** and declare capabilities:

| Capability | Role |
|------------|------|
| `catalog` | Schedule feed for Live Matches grids |
| `resolve` | Turn a match source ref into playable streams |

The host calls the same **`extract(ctx)`** entry with **`ctx.action`**:

| `ctx.action` | Purpose |
|--------------|---------|
| `catalog` | Return schedule rows |
| `resolve` | Return streams for `ctx.source`, `ctx.matchId`, `ctx.stream`, `ctx.embedUrl`, … |

Use a shared **`prelude`** for embed unlock helpers (see [`live/embed-st.js`](live/embed-st.js)).

**Live-only ctx helpers:**

```javascript
ctx.live.goatUnlock(bodyHex, goat, slot)
ctx.live.gasmUnlock(bodyHex, island, slot)
ctx.live.sportsEmbedUnlock(embedUrl)
ctx.live.sniffEmbed(url, referer)   // desktop/mobile only — skipped on Android TV
```

Reference: [`live/streamed.js`](live/streamed.js), [`live/manifest.json`](live/manifest.json).

---

## Catalog hub plugins (`kind: catalog`)

Shell tabs (Home, Anime, custom hubs) and feature catalogs (IPTV VOD) speak the **catalog hub protocol v1**.

### Entry point

Same **`extract(ctx)`** function — the host sets **`ctx.action`**:

| Action | `ctx.params` | Response `data` |
|--------|--------------|-----------------|
| `layout` | `page` | `pages.{page}.widgets[]` |
| `rail` | `rail`, `filter`, `sort`, `page`, `limit`, `cursor` | `items[]`, optional paging |
| `feed` | paging + filter | infinite scroll items |
| `search` | `query`, `page`, `limit`, `filter` | `items[]` |
| `details` | `id` | `meta` (+ optional `rails`) |
| `filters` | — | `fields[]` filter schema |
| `enrich` | `items` or `meta` | enriched payload (companion plugin) |

Use [`hubs/anime/_kit.js`](hubs/anime/_kit.js) helpers (`hubOk`, `hubFail`, `hubItems`, `hubAction`, …) or copy the envelope shape yourself.

### Response envelope

Both engine backends require a **one-element array**:

```json
[{
  "ok": true,
  "kit": 1,
  "protocol": 1,
  "action": "rail",
  "cache": { "etag": "my-rail-1", "maxAge": 600, "swr": 3600 },
  "data": { "items": [ … ] }
}]
```

Errors:

```json
[{
  "ok": false,
  "kit": 1,
  "protocol": 1,
  "action": "details",
  "error": { "code": "UPSTREAM", "message": "HTTP 503", "retryable": true }
}]
```

Error codes: `INVALID_ACTION`, `INVALID_PARAMS`, `NOT_FOUND`, `AUTH_REQUIRED`, `AUTH_EXPIRED`, `RATE_LIMIT`, `UPSTREAM`, `PARSE`, `UNSUPPORTED_KIT`, `CANCELLED`.

If `kit` > host kit version (`1` today), the shell shows **unsupported kit** — bump your plugin, not the host.

Fixtures: [`hubs/fixtures/anilist_rail.json`](hubs/fixtures/anilist_rail.json).

### Catalog meta items

Each browse card / details meta:

```javascript
{
  id: 'myhub:123',
  type: 'anime',              // opaque content type token
  name: 'Title',
  poster: 'https://…',
  background: 'https://…',
  description: '…',
  rating: 8.5,
  releaseInfo: '2024',
  genres: ['Action'],
  ids: { tmdb: '123', anilist: '456' },  // opaque upstream ids
  open: {                     // required for openable items
    surface: 'anime',         // host route: anime | drama | tmdb | arabic | …
    id: '456',                // opaque id for that route
    extract: {                // optional — passed to provider extract
      resolveType: 'anime',
      panelCategory: 'anime',
      ctx: { anilistId: 456, malId: 123 }
    }
  },
  videos: [ … ]               // episodes on details — opaque ids for play
}
```

The host routes on **`open.surface`** only — not on your plugin id or scraper name.

### Shell navigation

Add a shell tab with **`nav`** on a catalog plugin:

```json
"nav": {
  "tabId": "my_hub",
  "label": "My Hub",
  "order": 25,
  "icon": "forja://asset/nav/anime",
  "accent": "#FB7185",
  "defaultEnabled": true
}
```

Icons must use **`forja://asset/nav/…`** URIs (host asset catalog), not Flutter `assets/` paths.

### Capabilities

| Capability | Host behavior |
|------------|---------------|
| `nav` | Contributes shell tab (with `nav` block) |
| `layout`, `rail`, `feed` | Browse widgets |
| `search` | Top-bar Search → pack search action |
| `host_search` | Opens shared Cmd+F search overlay |
| `filters` | Merges chrome filters into search/rail params |
| `structured_search` | Advanced filter lens (TMDB-style) |
| `details` | Title details page |
| `enrich` | Companion-only — piped after rail/details |

### Enrich companions

Keep source JS data-only; declare a second plugin for TMDB match, extra images, etc.:

```json
{ "id": "my-hub", "entry": "hub.js", "enrich": "my-hub-enrich-tmdb" },
{ "id": "my-hub-enrich-tmdb", "entry": "enrich_tmdb.js", "capabilities": ["enrich"] }
```

The host runs `action: enrich` after `rail` / `details` and caches the merged result.

### Layout kit (`kit.*` widgets)

Compose hub pages in **`layout`** with typed kit widgets. The host maps each `type` to a Flutter widget; packs declare structure only — no hardcoded My List chrome in Dart.

| Type | Role | Key fields |
|------|------|------------|
| `kit.stack` | Vertical column | `children[]`, `expand: true` (last child fills viewport) |
| `kit.menu` | Underline filter menu | `items[]` (`id`, `label`), `toggle`, `focusUp` / `focusDown` |
| `kit.tabs` | Status / segment strip | `tabs[]`, `default`, `focusUp` / `focusDown` |
| `kit.list` | Host-backed grid | `source` (registered host backend, e.g. `my_list`), `kindMenu`, `statusTab` |
| `kit.row` | Horizontal rail | Same as legacy `rail` / `ranked` |

Legacy aliases still work: `stack` → `kit.stack`, `tabs` + `style: 'underline'` → `kit.menu`, `host.my_list` → `kit.list`.

Helpers in pack `_kit.js` (copy into your hub):

```javascript
kitStack('page', { expand: true }, [
  kitMenu('kind', [{ id: 'movie', label: 'Film' }, …], { toggle: true, focusDown: 'status' }),
  kitTabs('status', [{ id: 'watching', label: 'Watching' }, …], { default: 'plantowatch' }),
  kitList('grid', { source: 'my_list', kindMenu: 'kind', statusTab: 'status' }),
]);
```

Browse hubs keep `hero`, `mood`, `rail`, `host.continue`, etc. Use `kit.*` when you need composable chrome (menus, tabs, host lists) in one page tree.

`kit.list` binds to a **host source backend** (Model A): the pack declares layout + labels; the host owns persistence (local bookmarks, Simkl sync) and exposes data via registered source ids (`my_list` today). Optional `enrich` companion hydrates rows (e.g. TMDB details for Simkl stubs).

Pack `kit.menu` / `kit.tabs` render in the **shell top bar** (same slot as Home Search / Films / Series) — not inside the page body.

### Host helpers (catalog)

```javascript
ctx.host.tmdb.match({ title: 'One Piece', year: 1999, type: 'tv' })
// → { id, mediaType, poster, backdrop, overview, rating } | null
```

TMDB API key is injected by the host when the app is built with `TMDB_API_KEY` — do not hardcode keys in published packs.

Reference hubs: [`hubs/home/tmdb.js`](hubs/home/tmdb.js), [`hubs/anime/anilist.js`](hubs/anime/anilist.js), [`hubs/asian_drama/kisskh.js`](hubs/asian_drama/kisskh.js).

---

## Publishing

1. Host `manifest.json` + all `entry` / `prelude` files on HTTPS with correct CORS (GitHub raw works for public packs).
2. Give users the manifest URL.
3. **Never reuse a plugin `id` that exists in another installed pack** — install is rejected.
4. Prefer a stable pack `id` and semver `version` per release.

Signed manifests / sha256 verification are **not** implemented yet — distribute from sources you trust.

---

## Local development tips

| Task | How |
|------|-----|
| Edit official pack | Point Forja at local manifest path; **Reload** pack after JS changes |
| Test one provider | **Settings → Sources → Forja** — enable only your plugin; use **Sources → Forja** panel on a title |
| Test hub | Install hub manifest; open the tab; watch DevTools/logcat for `[catalog]` / plugin console lines |
| Engine smoke | `cd apps/forja && flutter test test/engine_test.dart` (uses `--assets=` pack path) |
| Catalog protocol | `flutter test test/catalog_protocol_test.dart` |

Run desktop with `--dart-define-from-file=../../.env` so hub TMDB match works.

---

## Platform notes

| Topic | Behavior |
|-------|----------|
| **Android TV** | WebView sniff paths are skipped (`ctx.live.sniffEmbed`, some legacy embed providers). Prefer pure HTTP/API extract in JS |
| **Parallel extract** | Sources **All** runs up to 10 plugins at once (5 on TV) |
| **Timeouts** | VOD ~30s, catalog/live ~45s per call |
| **Hop chain** | Avoid infinite `ctx.hop` loops — host has no cycle detection |

---

## Checklist before sharing a pack

- [ ] Unique pack `id` and plugin `id`s across the ecosystem you target
- [ ] Every `entry` / `prelude` path resolves from the manifest URL
- [ ] `version` bumped
- [ ] VOD plugins return `[]` on miss, not throw (throws become `[]` after log)
- [ ] Catalog plugins return `[envelope]` with matching `kit` / `protocol`
- [ ] Openable hub metas include valid `open.surface` + `open.id`
- [ ] Stream URLs include headers CDN expects
- [ ] Tested install + **Reload** + **Remove** from Settings

---

## Official reference packs

| Pack | Manifest | Learn |
|------|----------|-------|
| Providers | [`providers/manifest.json`](providers/manifest.json) | VOD extract, hops, crypto |
| Live | [`live/manifest.json`](live/manifest.json) | Schedule + resolve |
| Home hub | [`hubs/home/manifest.json`](hubs/home/manifest.json) | TMDB layout, structured search |
| Anime hub | [`hubs/anime/manifest.json`](hubs/anime/manifest.json) | AniList + enrich companion |
| Asian Drama | [`hubs/asian_drama/manifest.json`](hubs/asian_drama/manifest.json) | KissKH + enrich |
| IPTV VOD | [`iptv/vod/manifest.json`](iptv/vod/manifest.json) | Feature catalog without nav tab |

Questions / WIP specs: [RFC-067](../docs/rfc/fixed/067-[fixed]-forjahq-remote-plugin-pack.md) (remote packs), [RFC-068](../docs/rfc/fixed/068-[fixed]-engine-plugin-registry.md) (registry), [RFC-070](../docs/rfc/070-[partial]-catalog-hub-protocol.md) (hub protocol).
