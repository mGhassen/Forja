# Debrid

> Instant playback from cached torrents via your installed debrid pack.

## What it is

Debrid services store popular torrents on fast servers. When you enable a debrid plugin, Forja resolves a magnet to a direct HTTP link instead of peer-to-peer streaming — faster starts and less buffering for cached content.

Vendors ship as installable pack plugins (Real-Debrid, TorBox, AllDebrid, Premiumize, Debrid-Link). The app only calls the active plugin; uninstall the pack and magnets still play via the local torrent engine or LAN.

## Supported services

Whatever `kind: debrid` plugins you have installed (ForjaHQ Debrid pack includes Real-Debrid, TorBox, AllDebrid, Premiumize, and Debrid-Link).

## How to open it

**Settings → Addons → Debrid** (only while a debrid pack is installed) — pick the active plugin and enter its API key.

## What you can do

- Turn magnet cloud-resolve on by selecting an active debrid plugin (or clear it for local/LAN only)
- Save each plugin’s API key under that plugin’s settings
- Resolve torrents on media details through the active plugin when the title is cached remotely

## Setup

1. Install the Debrid pack (if it is not already installed)
2. Create an account with your chosen service
3. Open **Addons → Debrid**, select that plugin, paste the API key
4. Play a magnet — Forja resolves through the plugin when it is selected

## Tips

- Debrid only helps when the torrent is already cached on the service
- With no plugin selected, magnets use normal [torrent playback](../playback/torrent-playback.md)

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [TMDB details](../movies-tv/tmdb-details.md)
- [Torrent playback](../playback/torrent-playback.md)
