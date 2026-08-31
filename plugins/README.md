# ForjaHQ plugins

Official engine JS packs for [Forja](https://github.com/mGhassen/Forja) — maintained by **Forja Team**.

Six packs in this tree:

| Pack | Path | Role |
|------|------|------|
| **ForjaHQ Providers** | [`providers/manifest.json`](providers/manifest.json) | VOD / anime / drama scrapers + file-host hops |
| **ForjaHQ Live** | [`live/manifest.json`](live/manifest.json) | Live Matches resolve (`live/*.js` + `embed-st.js`) |
| **ForjaHQ Catalog** | [`catalog/manifest.json`](catalog/manifest.json) | Live schedule catalogs |
| **ForjaHQ Home** | [`hubs/home/manifest.json`](hubs/home/manifest.json) | Home catalog hub (TMDB) |
| **ForjaHQ Anime** | [`hubs/anime/manifest.json`](hubs/anime/manifest.json) | Anime catalog hub (AniList) |
| **ForjaHQ Asian Drama** | [`hubs/asian_drama/manifest.json`](hubs/asian_drama/manifest.json) | Asian Drama catalog hub (KissKH) |

Arabic (`hubs/arabic/`) is optional / out of product scope.

## Install in Forja

The Flutter host does **not** ship or hardcode pack inventory. Packs are **external**:

1. **Settings → Sources → Forja** — paste a manifest URL (`https://…/manifest.json` or local `file://` path on desktop dev).
2. **Profile sync** — signed-in users get lean pack rows from the cloud; the app hydrates full manifests on first use.

Point each manifest at the packs in this repo (e.g. raw GitHub URLs or your own CDN). Hub packs are required for Home / Anime / Asian Drama catalog tabs.

**Local dev:** install manifests with absolute paths to this checkout, e.g. `/path/to/Forja/plugins/providers/manifest.json`.

## Layout

| Path | Role |
|------|------|
| `providers/` | VOD extractors |
| `live/` | Live match resolvers |
| `catalog/` | Live schedule catalogs |
| `hubs/` | Catalog hub packs (home, anime, …) |

Each pack is a `manifest.json` plus JS entries referenced from the manifest.
