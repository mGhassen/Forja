# Torrent scrapers

> Built-in search across Knaben, The Pirate Bay, and Uindex.

## What it is

When you open a movie or series in torrent mode, Forja searches three built-in indexers in parallel: **Knaben**, **The Pirate Bay (TPB)**, and **Uindex**. Results are deduplicated by infohash and merged into the torrent list on the details screen.

## How to open it

Automatic on [Media details](../movies-tv/media-details.md) when you view torrent results.

## What you can do

- See combined results from all three indexers
- Sort by seeders, size, or other options (Settings → Sources)
- Play magnets or torrent files via [torrent playback](../playback/torrent-playback.md)
- On desktop, hover a torrent row in Sources to copy its magnet link

## Setup (if needed)

No API keys required. Adjust **sort preference** in Settings → Sources.

## Tips

- Add [Jackett](jackett.md) or [Prowlarr](prowlarr.md) for many more private and public indexers
- Use [Debrid](../sources/debrid.md) when a torrent is cached for instant playback

## Related

- [Torrent settings](../settings/torrent-settings.md)
- [Jackett](jackett.md)
- [Prowlarr](prowlarr.md)
