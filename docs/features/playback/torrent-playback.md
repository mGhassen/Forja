# Torrent playback

> Stream torrents without waiting for a full download — magnet to play in seconds.

## What it is

When you play a torrent or magnet link, Forja uses the built-in torrent engine (librqbit) to stream pieces over HTTP on localhost. The engine waits until the start of the selected file has enough bytes for the player to probe the container, then opens playback — you may see a short “starting engine” wait on slow swarms. Multi-file torrents show a file picker so you choose which video to play. Works from media details, the Magnet tab, or debrid-cached torrents.

## How to open it

- Pick a torrent on [Media details](../movies-tv/media-details.md); on desktop, hover a torrent row in Sources to copy its magnet
- Paste a magnet on the [Magnet player](../utilities/magnet-player.md) tab
- Play a debrid-resolved torrent link

## What you can do

- Start playback while the torrent still buffers
- Seek on the progress bar once duration is known (same as other VOD streams)
- Select which file to play in multi-file torrents
- Switch torrents / Stremio / Nuvio streams mid-playback via the link (magnet) button — opens the same right-side **Sources** panel as media details (**Torrents / Stremio / Nuvio** tabs, provider chips under the tabs, search, source cards). On **Android TV** the panel owns D-pad focus (same graph as details Sources); search needs **OK** before the keyboard; multi-file torrents use a D-pad file list. **Back** closes Filters if open, otherwise the panel — it does not leave the player. **Filters** stays closed until you tap the tune control. Opens on **Torrents** when you are playing a local magnet (including magnets that came from Stremio/Torrentio), otherwise Torrents when available (else Nuvio, then Stremio); results cached ~30 minutes; the **selected** category tab shows an animated **…** while that kind is still loading, and a **reload** icon for a fresh fetch; switching away cancels an in-flight load for the previous kind. New rows keep the list where you scrolled or hovered. Torrents and Stremio show every fetched row. Torrents has an **All** chip plus one chip per enabled built-in provider (and Jackett / Prowlarr when configured). **All** highlights every enabled built-in chip (Jackett / Prowlarr stay separate). Nuvio has an **All** chip (select every scraper) or tap individual scrapers (tap again clears their rows); more chips load lazily one at a time. Closing the panel stops any still-running category fetch. The link control also appears for **Stremio Direct / Nuvio** sessions even when the stream has no magnet (direct HTTP). Picking another **torrent** or Stremio/Torrentio **magnet** keeps the current video playing and shows the bottom-right loading card while the new magnet resolves; a fresh player opens only when the stream is ready. Direct HTTP Stremio/Nuvio picks still resolve and reload in-player. The layers **Source** server picker stays hidden during catalog Sources playback (magnet or Stremio Direct)
- On desktop, optionally show a live torrent stats card (Settings → Torrent stats, off by default) above the seek bar while controls are visible: download/upload speed, live peers, downloaded size / %, ETA. When Skip Intro or Next Episode is showing, the card lifts above those buttons
- Set how much torrent data to keep on disk in Settings (oldest idle downloads are removed when over the cap)

## Setup (if needed)

**Settings → Sources → Torrent engine:**
- Disk cache size (GB) — default 2 GB on desktop, 1 GB on phone and Android TV
- Connection limit

## Tips

- More seeders = smoother start; sort torrents by seeders in Settings
- First play of a magnet waits for the file head **and** a real video frame before playback is confirmed — dead or incomplete swarms time out with an error instead of freezing on a black screen. Duration is synced into the seek bar as soon as mpv reports it (often immediately; sometimes after more pieces land). Open caps format probe size so the player prefers the fetched head; after playback starts you can scrub anywhere — jumps past the downloaded buffer wait on those pieces and may buffer briefly
- Magnet metadata first uses a short hash-validated metadata-cache lookup, then falls back to DHT/trackers for up to about 90 seconds — cold or uncommon swarms can still take longer than desktop clients with an established DHT table
- After metadata, Forja waits for the start of the file (up to about 3 minutes, prefer ~256 KB) so the player can probe the container; playback can start once enough head bytes arrive even if the full probe target is not met yet
- Stremio/Torrentio magnet links are always resolved through the torrent engine or debrid — they are never opened as a local file path. Season-pack rows use the addon’s file index so the matching episode starts
- Closing Sources to pick a torrent does not abort the magnet resolve that is about to start
- Closing a torrent or switching titles deletes that download; leftover files stay under the disk cache cap
- [Debrid](../sources/debrid.md) avoids slow swarms when the torrent is already cached remotely
- On Android TV, Sources lists torrents without pairing; playing a magnet needs a paired desktop in [LAN](../settings/lan.md) (dialog if unpaired). Direct HTTP Stremio/Nuvio still play on the TV. Phones can play magnets locally, or via the desktop when paired.

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent settings](../settings/torrent-settings.md)
- [LAN](../settings/lan.md)
- [Magnet player](../utilities/magnet-player.md)
