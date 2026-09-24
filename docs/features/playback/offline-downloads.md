# Offline Downloads

> Save movies and episodes to watch without a network connection.

## What it is

Forja can download a resolved HTTP or HLS stream to this device. Manage the
queue and offline library under **Settings → Downloads**. Torrents and magnets
are not offline yet.

## How to start a download

- **Details** — tap the download icon next to Play / Sources. Sources opens;
  hover a stream row to push the card and reveal a right action rail with
  Download (same pattern as IPTV Portals). Row tap still plays.
- **Sources** — hover any HTTP stream row to push in the Download action;
  torrents toast that offline isn’t available yet. Downloading rows show
  progress with striped chrome; finished offline rows keep static stripes.
  Filters include **Offline** / **Online**.
- **Player** — use the download icon in the top bar to save the stream you’re
  watching (phone, Android TV Exo, and desktop).

Hover a stream row and tap Download — the card switches to a confirm face
(like IPTV portal delete / share), shows the stream size (exact for files,
~estimate for HLS) and free space, then Yes starts the transfer. Tap the row
or No to cancel. A toast then offers **View** → Settings → Downloads.

DASH (`.mpd`) and other playlist/page responses are rejected — only real
HTTP/HLS media files are saved.

## Settings → Downloads

| Tab | What you see |
|-----|----------------|
| **Active** | Queued, downloading, paused, or failed items — progress, speed, pause / resume / retry / cancel |
| **Completed** | Finished files — play offline, delete one, or delete all |

The header is a storage meter: offline library vs other space on the volume vs free, with the downloads folder path underneath.

## Offline play

On a completed row, tap **Play**. Forja opens the local file in the same player
(ExoPlayer and MediaKit stay available — pick from the Player menu as usual).

If Play says the file can’t be played, delete that row and download again — the
saved file is damaged or incomplete.

## Tips

- Interrupted downloads (app kill / crash) come back as **Paused** — resume them
  from Active.
- Magnets and session-only loopback URLs cannot be saved in this version.
- Live Sports and IPTV live channels are not part of offline Downloads.
- Downloading from the **player** refreshes the Forja provider first (short-lived
  stream links expire while you watch). If a link is already dead, Forja asks
  you to open Sources and download again.

## Related

- [Player](../playback/player.md)
- [Settings overview](../settings/overview.md)
- [Cache & data](../settings/cache-data.md)
