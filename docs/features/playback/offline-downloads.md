# Offline Downloads

> Save movies and episodes to watch without a network connection.

## What it is

Forja can download a resolved HTTP or HLS stream to this device. Manage the
queue under **Settings → Downloads**. Finished titles also show on the
**Downloads** tab: films, series, anime, and Asian dramas, one card each.
Torrents and magnets are not offline yet.

Offline Downloads is on phone and desktop.

## How to start a download

- **Sources** — hover any HTTP stream row to push in the Download action;
  torrents toast that offline isn’t available yet. A saved or in-progress
  download for this title appears at the top as soon as the panel opens,
  while providers are still searching. While a row is downloading (or paused),
  hover shows **Pause** / **Resume** and **X** to delete — not Download again.
  Finished offline rows keep static stripes. Hover an Offline row for
  **Play online** (the cloud stream) or **Delete** (removes that file).
  Filters include **Offline** / **Online**. Row tap on a saved stream plays
  the file on this device. The cloud button is the network stream.

Each source is its own file. Saving a second source for the same episode keeps both. Downloads lists every saved file under that episode, with the provider and stream. Tapping Download on a source you already saved says it is already saved.

Hover a stream row and tap Download — the card switches to a confirm face
(like IPTV portal delete / share), shows the stream size (exact for files,
~estimate for HLS) and free space, then Yes starts the transfer. Tap the row
or No to cancel. A toast then offers **View** → Settings → Downloads.

DASH (`.mpd`) and other playlist/page responses are rejected — only real
HTTP/HLS media files are saved.

## Settings → Downloads

| Tab | What you see |
|-----|----------------|
| **Active** | Queued, downloading, paused, or failed items — progress, speed, ETA, pause / resume / retry / cancel |
| **Completed** | Finished files — play offline, delete one, or delete all |

The header is a storage meter: offline library vs other space on the volume vs free, with the downloads folder path underneath. On desktop and phone, **Change** opens a folder picker for where new downloads save; **Default** restores the usual Downloads/Forja (or Documents) folder. Existing completed files stay where they were saved.

## Downloads tab

Each title is a poster card, including one that is still saving. It appears when the save starts, including when Downloads is already open. A saving poster has a progress bar. Open it and that card stays marked. Each file that is still saving shows percent, speed, and a bar.
The panel starts at the top of the page, beside the kind menu, with a rounded
top-left. It shows the backdrop, the title logo when there is one, the year,
and a short synopsis. A series lists each saved episode the way the player
does: the image, the title, and a short synopsis, under a season menu. The
files for that episode sit under it. Each file is a flat Sources row: the
provider and stream, the file size, and Offline. Play online and Delete sit
on that row. Hover highlights it the same way as Sources. Tap the row to
play the saved file. Play online opens the network stream. Delete removes
that file from this device. Saving an episode also stores that image and the
episode text, so the panel still shows them without a connection.

## Offline play

On a completed row in Settings, tap **Play**. In Sources, tap the Offline stream
row. From Downloads, tap a saved row. Forja opens the
local file in the same player (ExoPlayer and MediaKit stay available — pick
from the Player menu as usual). While that file is playing, the source button
shows an offline icon, the provider, and the stream name. Opening the source
list shows that same source, marked Offline. Play online drops the icon.

Play strips an image shell that some streams wrap around the video. If Play
still says the file can’t be played, delete that row and download again — the
saved file is damaged or incomplete.

A saved stream keeps its in-stream subtitles. They show in the subtitle menu
when you play that file.

## Tips

- Interrupted downloads (app kill / crash) come back as **Paused** — resume them
  from Active.
- Magnets and session-only loopback URLs cannot be saved in this version.
- Live Sports and IPTV live channels are not part of offline Downloads.

## Related

- [Player](../playback/player.md)
- [Settings overview](../settings/overview.md)
- [Cache & data](../settings/cache-data.md)
