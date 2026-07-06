# Scrapers overview

> How Forja finds torrents, streams, and subtitles on the web.

## What it is

**Scrapers** are the parts of Forja that fetch content from external websites and indexers — as opposed to official APIs (TMDB, Trakt) or protocols you configure (Jellyfin, Xtream). They power torrent search on details screens, direct streaming links, subtitles, and dedicated content hubs (anime, Arabic, etc.).

You don't install most scrapers separately; they're built in. Exceptions: **Nuvio** manifests, **Jackett**, and **Prowlarr**.

## Scraper types

| Type | What you get | Configure in |
|------|----------------|--------------|
| [Torrent](torrent.md) | Magnet/torrent results on details | Settings → Search & Torrents |
| [Jackett](jackett.md) / [Prowlarr](prowlarr.md) | Extra indexer results | Settings → Providers & Addons |
| [Nuvio](nuvio.md) | JS scraper stream links | Settings → Nuvio Addons |
| [WebStreamr sources](webstreamr-sources.md) | Country streaming sites | WebStreamr Settings |
| [WebStreamr extractors](webstreamr-extractors.md) | Embed host links | WebStreamr Settings |
| [Subtitle scrapers](subtitle-scrapers.md) | Sub tracks in player | Automatic |
| [Content hubs](content-hub-scrapers.md) | Anime, drama, comics, etc. | Built into each tab |

## Where results appear

- **Movie/series details** — torrent scrapers, Jackett, Prowlarr, Stremio, Nuvio
- **Direct streaming mode** — stream providers + WebStreamr + Nuvio
- **Player** — subtitle scrapers
- **Hub tabs** — Anime, Arabic, Manga, Live Matches, etc.

## Related

- [Media details](../movies-tv/media-details.md)
- [Direct streaming mode](../movies-tv/direct-streaming-mode.md)
- [WebStreamr settings](webstreamr-settings.md)
