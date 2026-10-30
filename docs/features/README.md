# Forja — User Guide

Your cinema universe in one app. This guide explains every **in-scope** feature — what it does and how to use it.

**How do I…?** Step-by-step task guides → **[how-to/](how-to/README.md)** (packs, Home filters, Stremio, Sources, IPTV, Live Sports, Simkl, LAN, …).

**Developer docs:** [DEVELOPMENT.md](../DEVELOPMENT.md) · [ARCHITECTURE.md](../ARCHITECTURE.md) · [Plugin SDK](https://github.com/mGhassen/forja-sdk) · [Plugin packs](https://github.com/mGhassen/forja-packs)  
**Archived tabs & verticals:** [archive/](archive/README.md) (Search, Discover, Jellyfin, Stremio, Music, Reading, …)

---

## Getting started

- [Navigation](getting-started/navigation.md) — tabs, customizable navbar
- [Platforms](getting-started/platforms.md) — Windows, macOS, Linux, Android, iOS

---

## Movies & TV

- [Home](movies-tv/home.md)
- [TMDB details](movies-tv/tmdb-details.md) — Home, My List, TMDB hub rows
- [Webstreaming](movies-tv/direct-streaming-mode.md)
- [My List](movies-tv/my-list.md)
- [Watch history](movies-tv/watch-history.md)
- [External lists](movies-tv/external-lists.md)

---

## Content hubs

- [Hub details](hubs/hub-details.md) — catalog-kit title pages (Anime, Asian Drama, …)
- [Anime](hubs/anime.md)
- [Asian Drama](hubs/asian-drama.md)
- [Arabic](hubs/arabic.md)
- [Aflem](hubs/aflem.md)
- [Shahid](hubs/shahid.md)
- [كرتون](hubs/cartoon.md)
- [Kids](hubs/kids.md)
- [Stremio](hubs/stremio-catalog.md) — installed Stremio addon catalogs


---

## Playback

- [Player](playback/player.md)
- [Offline Downloads](playback/offline-downloads.md)
- [Torrent playback](playback/torrent-playback.md)
- [Subtitles](playback/subtitles.md)
- [Audio tracks](playback/audio-tracks.md)
- [Playback speed](playback/playback-speed.md)
- [In-app mini player](playback/in-app-mini-player.md)
- [Picture-in-picture](playback/picture-in-picture.md)
- [Skip segments](playback/skip-segments.md)
- [Next episode](playback/next-episode.md)
- [External players](playback/external-players.md)

---

## Scrapers

How Forja finds torrents, streams, and subtitles from the web.

- [Scrapers overview](scrapers/README.md)
- [Torrent scrapers](scrapers/torrent.md) — Knaben, TPB, Uindex
- [Jackett](scrapers/jackett.md)
- [Prowlarr](scrapers/prowlarr.md)
- [Nuvio scrapers](scrapers/nuvio.md)
- [Subtitle scrapers](scrapers/subtitle-scrapers.md)
- [Content hub scrapers](scrapers/content-hub-scrapers.md)

---

## Sources & integrations

- [Debrid](sources/debrid.md)
- [Stream providers](sources/stream-providers.md)

---

## Live TV

- [Live Sports](live/live-sports.md)
- [IPTV — Xtream](live/iptv-xtream.md)
- [IPTV — M3U](live/iptv-m3u.md)
- [IPTV — Stalker](live/iptv-stalker.md)
- [IPTV — Catalog ops (admin)](live/iptv-catalog-ops.md) — operators: pool, credits, scrape worker

---

## Accounts

- [Trakt](accounts/trakt.md)
- [Simkl](accounts/simkl.md)
- [MDBList](accounts/mdblist.md)
- [Link Android TV](accounts/tv-connect.md) — desktop and TV code / QR → portal `/connect`
- [Cloud sync](settings/cloud-sync.md) — Forja account (Supabase)

---

## Settings

- [Overview](settings/overview.md)
- [Appearance](settings/appearance.md)
- [Playback settings](settings/playback-settings.md)
- [LAN](settings/lan.md) — desktop server, pairing, torrent relay to phone/TV
- [Cache & data](settings/cache-data.md)
- [Forja Sports](settings/forja-sports.md) — Catalog ↔ Xtream/Stalker for Live Sports
- [Torrent settings](settings/torrent-settings.md)
- [Forja Packs](settings/forja-packs.md)
- [Backup & restore](settings/backup-restore.md)
- [Features](settings/navigation-bar.md)
- [App updates](settings/app-updates.md)
- [Cloud sync](settings/cloud-sync.md)

---

## Coming soon

- [Casting](coming-soon/casting.md)

---

## Archived features

Tabs and verticals not in the default product surface — guides kept for reference:

[archive/README.md](archive/README.md) — Search, Discover, Similar, Magnet, Media Downloader, Jellyfin, Music, Reading, Stremio, Arabic hubs, …

---

## I want to…

Full index: **[how-to/](how-to/README.md)**. Quick links:

| Goal | Start here |
|------|------------|
| Install Official / Community packs | [Official](how-to/packs/install-official.md) · [Community](how-to/packs/install-community.md) |
| Install a pack from a URL | [Manifest URL](how-to/packs/install-from-url.md) |
| Add a Stremio addon and play | [Stremio](how-to/sources/stremio-addon.md) |
| Filter Home (Films / service / languages) | [Films/TV](how-to/home/filter-films-tv-categories.md) · [Streaming service](how-to/home/filter-streaming-service.md) · [SUB/DUB](how-to/home/filter-languages.md) |
| Play from Sources / Green Play | [Sources](how-to/sources/play-from-sources.md) · [Green Play](how-to/home/green-play.md) |
| Add debrid / play torrents | [Debrid](how-to/sources/debrid.md) · [Local torrents](how-to/sources/torrents-local.md) |
| Play torrents on TV via desktop | [LAN pair & play](how-to/lan/pair-and-play.md) |
| Add IPTV / watch Live Sports | [IPTV portal](how-to/live/add-iptv-portal.md) · [Live Sports](how-to/live/live-sports.md) |
| Connect Simkl / My List | [Simkl](how-to/accounts/connect-simkl.md) · [My List](how-to/home/my-list.md) |
| Show / reorder tabs | [Features](how-to/home/show-hide-tabs.md) |
| Clear cache or watch data | [Clear cache](how-to/data/clear-cache.md) |
| Link Android TV | [TV connect](how-to/accounts/link-tv.md) |

Reference (what a surface *is*): [TMDB details](movies-tv/tmdb-details.md) · [LAN](settings/lan.md) · [Live Sports](live/live-sports.md) · …
