# Player

> One player for movies, series, IPTV, and more — desktop and mobile.

## What it is

Forja routes all video playback through a unified player. Controls use a flat overlay (no glass chrome): **Back**, title with genre/runtime/year on the left, play/pause and ±10s skip with volume on the bottom-left, seek bar with hover frame preview on desktop (timestamp fallback when preview is unavailable), and sources, PiP, and fullscreen on the bottom-right. On mobile, sources open as a bottom sheet; on desktop, a right-side panel. The player handles torrent streams, direct HLS/MP4 links, debrid URLs, Jellyfin, and hub content.

## How to open it

Tap **Play** on any details screen, stream list, IPTV channel, or hub episode.

## What you can do

- Play, pause, seek (with hover preview on desktop when supported), and adjust volume
- Skip ±10 seconds
- Switch among available stream sources for the current title (not provider/server grid — that is a later release)
- Open subtitle and audio track menus
- Change playback speed
- Use picture-in-picture on Android and desktop
- Skip intro/recap/credits when IntroDB has data
- Jump to next episode for TV content
- Launch an external player instead of built-in (Settings)

## Tips

- If a stream fails, Forja may auto-try the next source in the list
- Seek preview needs a decodable frame; live or buffering streams may show time only
- Long sessions benefit from [torrent cache settings](../settings/torrent-settings.md) when streaming magnets

## Related

- [Torrent playback](torrent-playback.md)
- [Subtitles](subtitles.md)
- [External players](external-players.md)
- [Playback settings](../settings/playback-settings.md)
