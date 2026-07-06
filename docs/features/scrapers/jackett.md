# Jackett

> Connect your self-hosted Jackett instance for extra torrent indexers.

## What it is

[Jackett](https://github.com/Jackett/Jackett) aggregates hundreds of torrent sites behind one API. Point Forja at your Jackett URL and API key to merge those results into movie/series torrent search.

## How to open it

**Settings → Providers & Addons → Jackett** — enter URL and API key, then test connection.

## What you can do

- Add Jackett base URL and API key
- Test the connection from Settings
- See Jackett results alongside built-in [torrent scrapers](torrent.md) on details screens

## Setup

1. Run Jackett on your network (Docker, NAS, or PC)
2. Copy the API key from Jackett's UI
3. In Forja: paste **Base URL** (e.g. `http://192.168.1.10:9117`) and **API Key**
4. Tap **Test** to verify

## Tips

- Jackett must be reachable from the device running Forja (same LAN or VPN)
- More indexers in Jackett = more results, but also more noise — curate in Jackett

## Related

- [Prowlarr](prowlarr.md) — alternative *arr stack indexer
- [Torrent scrapers](torrent.md)
- [Media details](../movies-tv/media-details.md)
