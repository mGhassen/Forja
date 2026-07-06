# Debrid

> Instant playback from cached torrents via Real-Debrid, TorBox, and more.

## What it is

Debrid services store popular torrents on fast servers. When you enable debrid, Forja can resolve a magnet to a direct HTTP link instead of peer-to-peer streaming — faster starts and less buffering for cached content.

## Supported services

- **Real-Debrid** — API key or OAuth-style login
- **TorBox** — API key
- **AllDebrid** — API key
- **Premiumize** — API key
- **Debrid-Link** — API key

## How to open it

**Settings → Debrid** — enable debrid, pick a service, enter credentials.

## What you can do

- Toggle debrid on/off globally
- Select active service
- Save API keys or log into Real-Debrid
- Resolve torrents on [Media details](../movies-tv/media-details.md) through debrid when cached

## Setup

1. Create an account with your chosen service
2. Copy API key (or complete Real-Debrid login flow in app)
3. Enable **Use debrid for streams** in Settings

## Tips

- Debrid only helps when the torrent is already cached on the service
- Uncached torrents may still fall back to normal [torrent playback](../playback/torrent-playback.md)

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Media details](../movies-tv/media-details.md)
- [Torrent playback](../playback/torrent-playback.md)
