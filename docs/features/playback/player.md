# Player

> One player for movies, series, IPTV, and more — desktop and mobile.

## What it is

Forja routes all video playback through a unified player. Controls use a flat overlay (no glass chrome):

- **Top bar** — back arrow, centered title, **S# E#** for TV episodes, and **stream** (servers/sources), **Cast**, and **PiP** on the top right (platform-gated)
- **Paused overlay** — show logo, rating/year meta, and synopsis on the left when playback is paused (when TMDB metadata is available)
- **Center actions** — large play/pause and ±10s buttons in the middle while controls are visible (desktop: mouse hover; mobile: tap to show controls)
- **Bottom bar** — full-width seek bar, then play/pause, ±10s, volume, and **current / total** time on the left; episodes (TV), audio, subtitles, quality, settings, and fullscreen on the right
- **Floating menus** — seasons/episodes, servers→sources drill-down, audio, subtitles, quality, and settings open as the same compact popup panel above the control bar

Seek bar on desktop supports hover frame preview (timestamp fallback when preview is unavailable). Servers and sources share one drill-down popup (like seasons → episodes). The player handles torrent streams, direct HLS/MP4 links, debrid URLs, Jellyfin, and hub content.

## How to open it

Tap **Play** on any details screen, stream list, IPTV channel, or hub episode.

On desktop, playback opens in a **full-window layer** above the app shell — the left nav rail is hidden until you tap back.

## What you can do

- Play, pause, seek (with hover preview on desktop when supported), and adjust volume
- Skip ±10 seconds from the bottom bar or large center controls
- Open **Stream** (top right) to switch servers, then drill into sources on the active server (same panel flow as seasons/episodes)
- Open **Seasons / Episodes** from the bottom bar — streaming mode returns to details; torrent/Stremio/WebStreamr paths reload in-player
- Switch **audio**, **subtitles**, and **quality** from dedicated bottom-bar buttons
- Open **Settings** popup for speed, aspect ratio, loop, hardware decode, and subtitle style
- Use picture-in-picture on Android and desktop
- Cast on supported platforms (AirPlay / Chromecast — stub until native channels ship)
- Skip intro/recap/credits when IntroDB has data
- Jump to next episode for TV content
- Launch an external player instead of built-in (Settings)

## Tips

- If a stream fails, Forja may auto-try the next source in the list
- Seek preview needs a decodable frame; live or buffering streams may show time only
- Quality shows all detected HLS variants; single-quality streams say “No quality options”
- Long sessions benefit from [torrent cache settings](../settings/torrent-settings.md) when streaming magnets

## Related

- [Torrent playback](torrent-playback.md)
- [Subtitles](subtitles.md)
- [External players](external-players.md)
- [Playback settings](../settings/playback-settings.md)
