# Offline Downloads

> Save movies and episodes to watch without a network connection.

## What it is

Forja can download a resolved HTTP or HLS stream to this device. Manage the
queue and offline library under **Settings → Downloads**. Torrents and magnets
are not offline yet.

## How to start a download

- **Details** — tap the download icon next to Play / Sources. Sources opens;
  hover a stream row and tap the green download icon on the right (same reveal
  as portal actions). Row tap still plays.
- **Sources** — hover any HTTP stream row to reveal **Download**; torrents
  toast that offline isn’t available yet.
- **Player** — use the download icon in the top bar to save the stream you’re
  watching (phone, Android TV Exo, and desktop).

A toast confirms the enqueue; tap **View** to open Settings → Downloads.

DASH (`.mpd`) and other playlist/page responses are rejected — only real
HTTP/HLS media files are saved.

## Settings → Downloads

| Tab | What you see |
|-----|----------------|
| **Active** | Queued, downloading, paused, or failed items — progress, speed, pause / resume / retry / cancel |
| **Completed** | Finished files — play offline, delete one, or delete all |

The header shows space used by downloads and free space on the downloads folder.

## Offline play

On a completed row, tap **Play**. Forja opens the local file in the same player
(ExoPlayer and MediaKit stay available — pick from the Player menu as usual).

## Tips

- Interrupted downloads (app kill / crash) come back as **Paused** — resume them
  from Active.
- Magnets and session-only loopback URLs cannot be saved in this version.
- Live Sports and IPTV live channels are not part of offline Downloads.

## Related

- [Player](../playback/player.md)
- [Settings overview](../settings/overview.md)
- [Cache & data](../settings/cache-data.md)
