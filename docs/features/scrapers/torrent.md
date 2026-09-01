# Torrent scrapers

> Built-in search across multiple public torrent providers (ForjaHQ Torrent pack).

## What it is

When you open a movie or series in torrent mode, Forja searches the **enabled** built-in providers in parallel (Knaben, The Pirate Bay, UIndex, Torrents CSV, Nyaa, YTS, SolidTorrents, TheRARBG, and Torrentio when an IMDb id is available). Indexers ship in the **ForjaHQ Torrent** plugin pack (`plugins/torrent/manifest.json`) — install it under **Settings → Sources → Forja** like other engine packs. Rows appear as each provider returns — a slow indexer no longer holds the whole list empty. Results are deduplicated by infohash and merged into the torrent list. Each row shows which provider found it.

## How to open it

Automatic on [TMDB details](../movies-tv/tmdb-details.md) when you view torrent results.

## What you can do

- Open **Sources → Torrents** and pick a provider chip (only that indexer is searched) or **All** (every enabled provider — only the All chip stays highlighted). Tap **All** again to clear. From **All**, tap one provider to filter to it. Switching chips mid-search **stops** the previous indexer; tap it again to continue that search. While an indexer is still searching, that chip shows the same animated **…** as the Torrents tab.
- See combined results from enabled providers
- Toggle which providers appear/run in [Torrent settings](../settings/torrent-settings.md)
- Sort by seeders, size, or other options
- Play magnets or torrent files via [torrent playback](../playback/torrent-playback.md)
- On desktop, hover a torrent row in Sources to copy its magnet link

## Setup (if needed)

No API keys required. Install the **ForjaHQ Torrent** pack (manifest URL pointing at `plugins/torrent/manifest.json`). Turn providers on/off and set **sort preference** in Settings → Sources.

## Tips

- Add [Jackett](jackett.md) or [Prowlarr](prowlarr.md) for many more private and public indexers
- Use [Debrid](../sources/debrid.md) when a torrent is cached for instant playback
- Torrentio only runs when the title has an IMDb id

## Related

- [Torrent settings](../settings/torrent-settings.md)
- [Jackett](jackett.md)
- [Prowlarr](prowlarr.md)
