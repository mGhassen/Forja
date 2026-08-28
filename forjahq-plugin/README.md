# ForjaHQ Plugin

Official engine JS provider pack for [Forja](https://github.com/mGhassen/Forja) — maintained by **Forja Team**.

## Install in Forja

1. Open **Settings → Sources → Forja**
2. Paste the manifest URL (or use the built-in ForjaHQ URL on first launch)

The URL is **`FORJA_HQ_MANIFEST_URL`** in repo-root `.env` (see `.env.example`) — required; the app does not bake a host.

**Local dev:** point at your checkout (absolute path or `file://`):

```
/Users/you/Forja/forjahq-plugin/manifest.json
```

**CI / release:** remote raw URL, e.g.:

```
https://raw.githubusercontent.com/mGhassen/Forja/main/forjahq-plugin/manifest.json
```

3. Tap **Install** (or wait for first-boot auto-install)

## Layout

| Path | Role |
|------|------|
| `manifest.json` | Pack metadata (`id`, `version`) + `plugins[]` provider entries |
| `domains.json` | Forja-owned mirror registry for Indian movie/TV plugins (MoviesMod, HDHub4u, …) |
| `providers/` | VOD / anime / drama scrapers |
| `providers/hops/` | File-host hop resolvers |
| `live/` | Live resolve + shared `embed-st.js` |
| `catalog/` | Live schedule catalogs |

Each `plugins[]` entry points at a relative `entry` JS file. Optional `prelude` is another relative JS file the host prepends at load (e.g. shared live helpers). One manifest, many providers.

## Host-only (not in this pack)

GOAT / GASM / sportsembed unlock assets ship inside the Forja app (`apps/forja/assets/plugins/live/goat`, `live/gasm`, `live/sportsembed`).
