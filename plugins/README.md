# ForjaHQ plugins

Official engine JS packs for [Forja](https://github.com/mGhassen/Forja) — maintained by **Forja Team**.

Seven packs (install all seven):

| Pack | Path | Role |
|------|------|------|
| **ForjaHQ Providers** | [`providers/manifest.json`](providers/manifest.json) | VOD / anime / drama scrapers + file-host hops |
| **ForjaHQ Live** | [`live/manifest.json`](live/manifest.json) | Live Matches resolve (`live/*.js` + `embed-st.js`) |
| **ForjaHQ Catalog** | [`catalog/manifest.json`](catalog/manifest.json) | Live schedule catalogs |
| **ForjaHQ Home** | [`hubs/home/manifest.json`](hubs/home/manifest.json) | Home catalog hub (TMDB) |
| **ForjaHQ Anime** | [`hubs/anime/manifest.json`](hubs/anime/manifest.json) | Anime catalog hub (AniList) |
| **ForjaHQ Asian Drama** | [`hubs/asian_drama/manifest.json`](hubs/asian_drama/manifest.json) | Asian Drama catalog hub (KissKH) |
| **ForjaHQ Arabic** | [`hubs/arabic/manifest.json`](hubs/arabic/manifest.json) | Arabic catalog hub (layout stub) |

## Install in Forja

Set in repo-root `.env` (see `.env.example`):

```
FORJA_HQ_PROVIDERS_MANIFEST_URL=…/plugins/providers/manifest.json
FORJA_HQ_LIVE_MANIFEST_URL=…/plugins/live/manifest.json
FORJA_HQ_CATALOG_MANIFEST_URL=…/plugins/catalog/manifest.json
FORJA_HQ_HOME_MANIFEST_URL=…/plugins/hubs/home/manifest.json
FORJA_HQ_ANIME_MANIFEST_URL=…/plugins/hubs/anime/manifest.json
FORJA_HQ_ASIAN_DRAMA_MANIFEST_URL=…/plugins/hubs/asian_drama/manifest.json
FORJA_HQ_ARABIC_MANIFEST_URL=…/plugins/hubs/arabic/manifest.json
```

All seven are required — without the four hub packs the engine refuses to boot
(Home / Anime / Asian Drama / Arabic tabs have no plugin). Arabic stays
`defaultEnabled: false` in Features until sources ship.

Local absolute paths or `https://raw.githubusercontent.com/…` both work. The app auto-installs on first launch; **Settings → Sources → Forja** can Refresh / Retry.

**Local checkout tip:** `FORJA_HQ_FORCE_PLUGIN_ENV=true` installs from those local URLs and disables cloud GitHub ForjaHQ packs. `false` (default) prefers cloud Profile ForjaHQ URLs when present and disables the local copies.

## Layout

| Path | Role |
|------|------|
| `providers/` | Provider + hop scripts + pack manifest |
| `live/` | Live resolve + shared prelude |
| `catalog/` | Catalog scripts |
| `hubs/home/` | TMDB Home + `_kit.js` |
| `hubs/anime/` | AniList hub + `_kit.js` |
| `hubs/asian_drama/` | KissKH hub + `_kit.js` |
| `hubs/arabic/` | Arabic hub stub + `_kit.js` |
| `hubs/fixtures/` | Protocol conformance fixtures |
| `domains.json` | Forja-owned mirror registry (MoviesMod, HDHub4u, …) |

Each `plugins[]` entry uses a path relative to that pack’s folder. Optional `prelude` is relative the same way.

## Catalog hub plugins (`kind: catalog`)

Hub plugins answer the **catalog protocol** (`protocol: 1`, `kit: 1`) instead of returning streams:

- Settings → Sources → Forja groups them under the **Hubs** tab (`EngineCategories.hubCatalog`). Live schedule feeds stay under **Catalog** (`types: catalog`, `kind: http`).
- Declare `capabilities` including **`nav`** plus a `nav` block (`tabId`, `label`, `order`, `defaultEnabled`, …). The host registers that tab under **Settings → Features** on install — independent of the plugin’s Sources on/off switch.
- `extract(ctx)` resolves to a **one-element array** holding the envelope — `[{ ok, kit, protocol, action, data, cache, error }]`. Both engine paths only carry a JSON array back.
- `ctx.action` is the requested action (`layout`, `rail`, `search`, `details`, `filters`).
- First-class request fields: **`ctx.params`**, **`ctx.auth`**, **`ctx.cache`**, **`ctx.kit`**, **`ctx.protocol`** (R70-A12). `_kit.js` still accepts a legacy `ctx.config.__request` fallback.
- `nav` in the manifest registers the shell tab (no `nav.replace`).
