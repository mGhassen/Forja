# Forja — User Guide

Your cinema universe in one app. This guide explains every **in-scope** feature — what it does and how to use it.

**Developer docs:** [DEVELOPMENT.md](../DEVELOPMENT.md) · [ARCHITECTURE.md](../ARCHITECTURE.md) · [Plugin packs](../../plugins/DEVELOPING.md)  
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
- [Brstej](hubs/brstej.md)
- [كرتون](hubs/cartoon.md)

---

## Playback

- [Player](playback/player.md)
- [Torrent playback](playback/torrent-playback.md)
- [Subtitles](playback/subtitles.md)
- [Audio tracks](playback/audio-tracks.md)
- [Playback speed](playback/playback-speed.md)
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

- [Live Matches](live/live-matches.md)
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
- [Forja Sports](settings/forja-sports.md) — Catalog ↔ Xtream/Stalker for Live Matches
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

| Goal | Start here |
|------|------------|
| Watch a movie from Home | [TMDB details](movies-tv/tmdb-details.md) → [Torrent scrapers](scrapers/torrent.md) → [Debrid](sources/debrid.md) |
| Play torrents on Android TV via desktop | [LAN](settings/lan.md) |
| Watch without torrents | [Webstreaming](movies-tv/direct-streaming-mode.md) → [Stream providers](sources/stream-providers.md) |
| Add more stream sources | [Nuvio scrapers](scrapers/nuvio.md) · [Stream providers](sources/stream-providers.md) |
| Watch anime or Asian drama | [Anime](hubs/anime.md) / [Asian Drama](hubs/asian-drama.md) → [Hub details](hubs/hub-details.md) |
| Watch Arabic cinema | [Arabic](hubs/arabic.md) → [Hub details](hubs/hub-details.md) |
| Watch Brstej series | [Brstej](hubs/brstej.md) → [Hub details](hubs/hub-details.md) |
| Watch Arabic cartoons | [كرتون](hubs/cartoon.md) → [Hub details](hubs/hub-details.md) |
| Watch live sports | [Live Matches](live/live-matches.md) |
| Resume where I left off | [Watch history](movies-tv/watch-history.md) |
| Clear cache or watch history | [Cache & data](settings/cache-data.md) |
| Customize the app | [Settings overview](settings/overview.md) · [Features](settings/navigation-bar.md) |
| Opt in to crash reports | [App updates](settings/app-updates.md) |
| Sign in with a code or QR | [Link Android TV](accounts/tv-connect.md) |
