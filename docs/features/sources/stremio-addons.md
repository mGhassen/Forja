# Stremio addons

> Install Stremio-compatible addons for catalogs, streams, search, and subtitles.

## What it is

Stremio addons are manifest-based extensions. Forja supports installing the same manifest URLs as Stremio — for browsing catalogs on Home, searching in the Search tab, streaming on details screens, and fetching subtitles in the player.

## How to open it

**Settings → Providers & Addons → Stremio Addons**

## What you can do

- Paste a manifest URL and install
- View installed addons and remove them
- Browse catalogs ([Stremio catalog](../movies-tv/stremio-catalog.md))
- Search addon content ([Search](../movies-tv/search.md))
- Play addon streams from [Media details](../movies-tv/media-details.md)
- Use subtitle-capable addons in the [player](../playback/subtitles.md)

## Setup

1. Find a Stremio addon manifest URL (ends with `/manifest.json`)
2. Paste in **Install Stremio Addon** and tap Install
3. Addon appears in installed list — no Stremio app required

## Tips

- Not every addon implements catalog, stream, and search — check the addon's manifest resources
- Community addon lists change frequently — verify manifests are trustworthy
- **Hash-based streams** (`infoHash`, e.g. Torrentio): on desktop and Android, Forja plays these via the local torrent engine or debrid. On **web** and future TV builds (`constrained` profile), only direct `url` streams and debrid-resolved hashes work — hash-only addons need debrid configured or streams are hidden

## Platform playback

| Platform | `url` streams | `infoHash` (no debrid) | `infoHash` + debrid |
|----------|---------------|------------------------|---------------------|
| Desktop, Android, iOS | Play direct | Local torrent engine | Debrid URL |
| Web, TV (planned) | Play direct | Requires debrid | Debrid URL |

Capability profile: `PlatformPlayback.capabilities` in `packages/api/lib/playback/platform/playback_profile.dart`. Stream resolution: `resolveStremioStream()` in `stremio_stream_resolver.dart`.

## Related

- [Stremio catalog](../movies-tv/stremio-catalog.md)
- [Search](../movies-tv/search.md)
- [Media details](../movies-tv/media-details.md)
