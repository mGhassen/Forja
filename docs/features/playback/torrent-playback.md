# Torrent playback

> Stream torrents without waiting for a full download — magnet to play in seconds.

## What it is

When you play a torrent or magnet link, Forja uses the built-in torrent engine (librqbit) to stream pieces over HTTP on localhost. The engine waits until the start of the selected file has enough bytes for the player to probe the container, then opens playback — you may see a short “starting engine” wait on slow swarms. Multi-file torrents show a file picker so you choose which video to play. Works from media details, the Magnet tab, or debrid-cached torrents.

## How to open it

- Pick a torrent on [Media details](../movies-tv/media-details.md)
- Paste a magnet on the [Magnet player](../utilities/magnet-player.md) tab
- Play a debrid-resolved torrent link

## What you can do

- Start playback while the torrent still buffers
- Select which file to play in multi-file torrents
- Switch torrents / Stremio / Nuvio streams mid-playback via the link (magnet) button — opens the same right-side **Sources** panel as media details (**All / Torrents / Stremio / Nuvio**, provider chips, filters, source cards). Opens on **All** when more than one kind is enabled (loads every enabled category; results cached ~30 minutes); each category chip has a **reload** icon for a fresh fetch. Closing the panel stops any still-running category fetch. The link control also appears for **Stremio Direct / Nuvio** sessions even when the stream has no magnet (direct HTTP). Picking a result resolves and reloads in-player. The layers **Source** server picker stays hidden during catalog Sources playback (magnet or Stremio Direct)
- On desktop, optionally show a live torrent stats card (Settings → Torrent stats, off by default) above the seek bar while controls are visible: download/upload speed, live peers, downloaded size / %, ETA. When Skip Intro or Next Episode is showing, the card lifts above those buttons
- Adjust cache type and size in Settings for smoother streaming

## Setup (if needed)

**Settings → Sources → Torrent engine:**
- Cache type: RAM or disk
- RAM cache size (MB)
- Connection limit

## Tips

- More seeders = smoother start; sort torrents by seeders in Settings
- First play of a magnet waits for the file head before video starts — dead swarms time out instead of flashing a format error
- Disk cache helps on low-RAM devices for large files
- [Debrid](../sources/debrid.md) avoids slow swarms when the torrent is already cached remotely

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent settings](../settings/torrent-settings.md)
- [Magnet player](../utilities/magnet-player.md)
