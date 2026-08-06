# Torrent scrapers

> Built-in search across multiple public torrent providers.

## What it is

When you open a movie or series in torrent mode, Forja searches the **enabled** built-in providers in parallel (Knaben, The Pirate Bay, UIndex, Torrents CSV, Nyaa, YTS, SolidTorrents, TheRARBG, and Torrentio when an IMDb id is available). Results are deduplicated by infohash and merged into the torrent list. Each row shows which provider found it.

## How to open it

Automatic on [Media details](../movies-tv/media-details.md) when you view torrent results.

## What you can do

- See combined results from enabled providers
- Toggle which providers run in [Torrent settings](../settings/torrent-settings.md)
- Sort by seeders, size, or other options
- Play magnets or torrent files via [torrent playback](../playback/torrent-playback.md)
- On desktop, hover a torrent row in Sources to copy its magnet link

## Setup (if needed)

No API keys required. Turn providers on/off and set **sort preference** in Settings → Sources.

## Tips

- Add [Jackett](jackett.md) or [Prowlarr](prowlarr.md) for many more private and public indexers
- Use [Debrid](../sources/debrid.md) when a torrent is cached for instant playback
- Torrentio only runs when the title has an IMDb id

## Related

- [Torrent settings](../settings/torrent-settings.md)
- [Jackett](jackett.md)
- [Prowlarr](prowlarr.md)
