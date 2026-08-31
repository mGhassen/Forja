# Scrapers overview

> How Forja finds torrents, streams, and subtitles on the web.

## What it is

**Scrapers** are the parts of Forja that fetch content from external websites and indexers — as opposed to official APIs (TMDB, Trakt) or protocols you configure (Xtream). They power torrent search on details screens, direct streaming links, subtitles, and dedicated content hubs (anime, drama, etc.).

You don't install most scrapers separately; they're built in. Exceptions: **Nuvio** manifests, **Jackett**, and **Prowlarr**.

## Scraper types

| Type | What you get | Configure in |
|------|----------------|--------------|
| [Torrent](torrent.md) | Magnet/torrent results on details | Settings → Sources |
| [Jackett](jackett.md) / [Prowlarr](prowlarr.md) | Extra indexer results (admin) | Settings → Sources |
| [Nuvio](nuvio.md) | JS scraper links in **Sources** (Direct torrent) | Settings → Nuvio Addons |
| [Subtitle scrapers](subtitle-scrapers.md) | Sub tracks in player | Automatic |
| [Content hubs](content-hub-scrapers.md) | Anime, drama, live sports | Built into each tab |

## Where results appear

- **[TMDB details](../movies-tv/tmdb-details.md)** — torrent scrapers (Forja), Jackett, Prowlarr, **Nuvio** (Sources panel)
- **Webstreaming** (green **Play**) — VidLink, Videasy, engine providers, etc. — **not** Nuvio
- **Player** — subtitle scrapers
- **Hub tabs** — Anime, Asian Drama, Live Matches ([Hub details](../hubs/hub-details.md))

## Related

- [TMDB details](../movies-tv/tmdb-details.md)
- [Direct streaming mode](../movies-tv/direct-streaming-mode.md)
