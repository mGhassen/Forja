# ForjaHQ plugins

Official engine JS packs for [Forja](https://github.com/mGhassen/Forja) — maintained by **Forja Team**.

**Community developers:** [DEVELOPING.md](DEVELOPING.md) — manifest schema, `extract(ctx)` / `search(ctx)` API, catalog hub protocol. **Contracts:** [sdk/contract.json](sdk/contract.json) + [sdk/schema/](sdk/schema/).

Nine official packs in this tree (web catalog is generated from these manifests — run `node scripts/generate-plugin-catalog.mjs` after adding a pack):

| Pack | Path | Role |
|------|------|------|
| **ForjaHQ Providers** | [`providers/manifest.json`](providers/manifest.json) | VOD / anime / drama scrapers + file-host hops |
| **ForjaHQ Catalog** | [`catalog/manifest.json`](catalog/manifest.json) | Live Matches schedule catalogs |
| **ForjaHQ Live** | [`live/manifest.json`](live/manifest.json) | Live Matches stream resolve (Forja Live) |
| **ForjaHQ Torrent** | [`torrent/manifest.json`](torrent/manifest.json) | Builtin torrent indexer search (`kind: torrent`) |
| **ForjaHQ Home** | [`hubs/home/manifest.json`](hubs/home/manifest.json) | Home catalog hub (TMDB) |
| **ForjaHQ Anime** | [`hubs/anime/manifest.json`](hubs/anime/manifest.json) | Anime catalog hub (AniList) |
| **ForjaHQ Asian Drama** | [`hubs/asian_drama/manifest.json`](hubs/asian_drama/manifest.json) | Asian Drama catalog hub (KissKH) |
| **ForjaHQ My List** | [`hubs/my_list/manifest.json`](hubs/my_list/manifest.json) | My List hub (local + Simkl via host widget) |
| **ForjaHQ IPTV VOD** | [`iptv/vod/manifest.json`](iptv/vod/manifest.json) | IPTV portal VOD details + optional TMDB enrich (no shell tab) |

Arabic (`hubs/arabic/`) is optional / out of product scope.

## Install in Forja

The Flutter host does **not** ship or hardcode pack inventory. Packs are **external**:

1. **Settings → Sources → Forja** — paste a manifest URL (`https://…/manifest.json` or local `file://` path on desktop dev).
2. **Profile sync** — signed-in users get lean pack rows from the cloud; the app hydrates full manifests on first use.

Point each manifest at the packs in this repo (e.g. raw GitHub URLs or your own CDN). Hub packs cover Home, Anime, Asian Drama, and My List catalog tabs. Install **IPTV VOD** separately for IPTV Movies/Series hub details (`FORJA_HQ_IPTV_VOD_MANIFEST_URL` in `.env.example`).

**Local dev:** install manifests with absolute paths to this checkout, e.g. `/path/to/Forja/plugins/providers/manifest.json`.

## Layout

| Path | Role |
|------|------|
| `providers/` | VOD extractors |
| `torrent/` | Torrent indexer search plugins |
| `live/` | Live match resolvers |
| `catalog/` | Live schedule catalogs |
| `iptv/` | IPTV feature packs (VOD details — not shell hub tabs) |
| `hubs/` | Catalog hub packs (home, anime, …) |
| `sdk/` | JSON Schema contracts + canonical JS kits |

Each pack is a `manifest.json` plus JS entries referenced from the manifest.
