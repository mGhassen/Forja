# ForjaHQ plugins

Official engine JS packs for [Forja](https://github.com/mGhassen/Forja) — maintained by **Forja Team**.

Three packs (install all three):

| Pack | Path | Role |
|------|------|------|
| **ForjaHQ Providers** | [`providers/manifest.json`](providers/manifest.json) | VOD / anime / drama scrapers + file-host hops |
| **ForjaHQ Live** | [`live/manifest.json`](live/manifest.json) | Live Matches resolve (`live/*.js` + `embed-st.js`) |
| **ForjaHQ Catalog** | [`catalog/manifest.json`](catalog/manifest.json) | Live schedule catalogs |

## Install in Forja

Set in repo-root `.env` (see `.env.example`):

```
FORJA_HQ_PROVIDERS_MANIFEST_URL=…/plugins/providers/manifest.json
FORJA_HQ_LIVE_MANIFEST_URL=…/plugins/live/manifest.json
FORJA_HQ_CATALOG_MANIFEST_URL=…/plugins/catalog/manifest.json
```

Local absolute paths or `https://raw.githubusercontent.com/…` both work. The app auto-installs on first launch; **Settings → Sources → Forja** can Refresh / Retry.

**Local checkout tip:** set `FORJA_HQ_FORCE_PLUGIN_ENV=true` so every boot reinstalls from those URLs and drops a previously installed GitHub copy of the same pack ids (otherwise cached cloud scripts keep winning).

## Layout

| Path | Role |
|------|------|
| `providers/` | Provider + hop scripts + pack manifest |
| `live/` | Live resolve + shared prelude |
| `catalog/` | Catalog scripts |
| `domains.json` | Forja-owned mirror registry (MoviesMod, HDHub4u, …) |

Each `plugins[]` entry uses a path relative to that pack’s folder. Optional `prelude` is relative the same way.
