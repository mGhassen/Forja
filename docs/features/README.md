# Forja — User Guide

Your cinema universe in one app. This guide explains every feature — what it does and how to use it.

**Developer docs:** [DEVELOPMENT.md](../DEVELOPMENT.md) · [ARCHITECTURE.md](../ARCHITECTURE.md)

---

## Getting started

- [Navigation](getting-started/navigation.md) — tabs, customizable navbar
- [Platforms](getting-started/platforms.md) — Windows, macOS, Linux, Android, iOS

---

## Movies & TV

- [Home](movies-tv/home.md)
- [Discover](movies-tv/discover.md)
- [Search](movies-tv/search.md)
- [Similar](movies-tv/similar.md)
- [Media details](movies-tv/media-details.md)
- [Webstreaming](movies-tv/direct-streaming-mode.md)
- [Stremio catalog](movies-tv/stremio-catalog.md)
- [My List](movies-tv/my-list.md)
- [Watch history](movies-tv/watch-history.md)
- [External lists](movies-tv/external-lists.md)

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
- [WebStreamr sources](scrapers/webstreamr-sources.md)
- [WebStreamr extractors](scrapers/webstreamr-extractors.md)
- [WebStreamr settings](scrapers/webstreamr-settings.md)
- [Subtitle scrapers](scrapers/subtitle-scrapers.md)
- [Content hub scrapers](scrapers/content-hub-scrapers.md)

---

## Sources & integrations

- [Stremio addons](sources/stremio-addons.md)
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

## Jellyfin

- [Jellyfin](jellyfin/jellyfin.md)

---

## Music

- [Music](music/music.md)
- [Music downloads](music/music-downloads.md)

---

## Reading

- [Manga](reading/manga.md)
- [Comics](reading/comics.md)
- [Books](reading/books.md)
- [Audiobooks](reading/audiobooks.md)
- [Generate audiobook](reading/generate-audiobook.md)

---

## Content hubs

- [Anime](hubs/anime.md)
- [Anime Arabic](hubs/anime-arabic.md)
- [Asian Drama](hubs/asian-drama.md)
- [Arabic cinema](hubs/arabic-cinema.md)

---

## Utilities

- [Magnet player](utilities/magnet-player.md)
- [Media Downloader](utilities/media-downloader.md)

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
- [My IPTV sports](settings/my-iptv-sports.md) — ESPN ↔ Xtream for Live Matches
- [Torrent settings](settings/torrent-settings.md)
- [Backup & restore](settings/backup-restore.md)
- [Features](settings/navigation-bar.md)
- [App updates](settings/app-updates.md)
- [Cloud sync](settings/cloud-sync.md)

---

## Coming soon

- [Casting](coming-soon/casting.md)

---

## I want to…

| Goal | Start here |
|------|------------|
| Watch a movie from torrents | [Media details](movies-tv/media-details.md) → [Torrent scrapers](scrapers/torrent.md) → [Debrid](sources/debrid.md) |
| Play torrents on Android TV via desktop | [LAN](settings/lan.md) |
| Watch without torrents | [Webstreaming](movies-tv/direct-streaming-mode.md) → [Stream providers](sources/stream-providers.md) |
| Add more stream sources | [Nuvio scrapers](scrapers/nuvio.md) · [WebStreamr settings](scrapers/webstreamr-settings.md) |
| Watch live sports | [Live Matches](live/live-matches.md) |
| Connect my home server | [Jellyfin](jellyfin/jellyfin.md) |
| Resume where I left off | [Watch history](movies-tv/watch-history.md) |
| Clear cache or watch history | [Cache & data](settings/cache-data.md) |
| Customize the app | [Settings overview](settings/overview.md) · [Features](settings/navigation-bar.md) |
| Opt in to crash reports | [App updates](settings/app-updates.md) |
| Sign in with a code or QR | [Link Android TV](accounts/tv-connect.md) |
