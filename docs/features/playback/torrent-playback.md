# Torrent playback

> Stream torrents without waiting for a full download — magnet to play in seconds.

## What it is

When you play a torrent or magnet link, Forja uses the built-in torrent engine (librqbit) to stream pieces over HTTP on localhost. Multi-file torrents show a file picker so you choose which video to play. Works from media details, the Magnet tab, or debrid-cached torrents.

## How to open it

- Pick a torrent on [Media details](../movies-tv/media-details.md)
- Paste a magnet on the [Magnet player](../utilities/magnet-player.md) tab
- Play a debrid-resolved torrent link

## What you can do

- Start playback while the torrent still buffers
- Select which file to play in multi-file torrents
- Switch torrents mid-playback via the link (magnet) button — opens the same right-side **Sources** panel as media details (torrent search list with Forja / Jackett / Prowlarr chips, filters, and source cards). Picking a torrent resolves and reloads in-player
- On desktop, optionally show a live torrent stats card (Settings → Torrent stats, off by default) above the seek bar while controls are visible: download/upload speed, live peers, downloaded size / %, ETA
- Adjust cache type and size in Settings for smoother streaming

## Setup (if needed)

**Settings → Search & Torrents → Torrent engine:**
- Cache type: RAM or disk
- RAM cache size (MB)
- Connection limit

## Tips

- More seeders = smoother start; sort torrents by seeders in Settings
- Disk cache helps on low-RAM devices for large files
- [Debrid](../sources/debrid.md) avoids slow swarms when the torrent is already cached remotely

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent settings](../settings/torrent-settings.md)
- [Magnet player](../utilities/magnet-player.md)
