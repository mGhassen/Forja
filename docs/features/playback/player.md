# Player

> One player for movies, series, IPTV, and more — desktop and mobile.

## What it is

Forja routes all video playback through a unified player. Controls use a flat overlay (no glass chrome):

- **Top bar** — back arrow, centered title, **S# E#** for TV episodes, and **Cast** and **PiP** on the top right (platform-gated)
- **Paused overlay** — show logo, rating/year meta, and synopsis on the left when playback is paused (when TMDB metadata is available)
- **Center actions** — large play/pause and ±10s buttons in the middle while controls are visible; hidden while checking sources or buffering (status roulette takes the center instead)
- **Status roulette** — center-right slide-up indicator when checking sources, switching servers, buffering, or auto-fallback (no bottom snackbars)
- **Bottom bar** — full-width seek bar, then play/pause, ±10s, volume, and **current / total** time on the left; **Sources** (torrent search panel when playing a magnet — same as media-details Sources), stream **Sources** / **Servers** when applicable, episodes (TV), audio, subtitles, quality, settings, and fullscreen on the right. On desktop torrent playback, when **Settings → Torrent stats** is on, a transparent stats card sits bottom-right above the seek bar while controls are visible (download/upload speed, peers, download size/%, ETA). It lifts above Skip Intro / Next Episode when those buttons are showing. Seeders show as — unless indexer metadata is available later — librqbit does not expose a live seeder count.
- **Floating menus** — servers, sources, audio, subtitles, quality, and settings open as compact popup panels anchored to the button you tapped (above or below, depending on space). Dismiss with the borderless **Close** control (soft circular highlight on hover — no outline box)
- **Episodes / Sources panels** — TV **Episodes** and torrent **Sources** (magnet button) open right-side panels. Player **Sources** uses a translucent dark shell (no freeze-frame image behind it). **Filters** from Sources docks as a second panel to the left of Sources and may frost a captured video frame. Episodes include season picker, numbered range chips (**1 - 50**, **51 - 100**, …) when the list is long, episode thumbnails, runtime, synopsis, and resume progress. Close with the borderless **Close** control in the header

Seek bar on desktop supports hover frame preview (timestamp fallback when preview is unavailable). **Servers** and **Sources** are separate bottom-right buttons with their own popup lists. The player handles torrent streams, direct HLS/MP4 links, debrid URLs, Jellyfin, and hub content.

## How to open it

Tap **Play** on any details screen, stream list, IPTV channel, or hub episode.

On desktop, playback opens in a **full-window layer** above the app shell — the left nav rail is hidden until you tap back.

## What you can do

- Play, pause, seek (with hover preview on desktop when supported), and adjust volume
- Double-click the video (desktop) to enter/exit fullscreen — same as **F** or the fullscreen button
- Skip ±10 seconds from the bottom bar or large center controls
- Open **Servers** (bottom right, cloud icon) to switch provider by real name (e.g. Vidsrc, WebStreamr); open **Sources** (bottom right, list icon) to pick a stream from the current server
- Open **Episodes** from the bottom bar — a right-side panel lists the season’s episodes with thumbnail, title, runtime, and synopsis; switch season from the header when the show has multiple seasons; use numbered range chips beside the season control when there are more than 50 episodes. Picking another episode resolves the stream and reloads in-player (you stay in the player)
- Switch **audio**, **subtitles**, and **quality** from dedicated bottom-bar buttons
- Open **Settings** popup for speed, aspect ratio, loop, hardware decode, and subtitle style. On desktop torrent sessions, toggle **Torrent stats** (off by default) to show live download/peer info above the seek bar while controls are visible
- Use picture-in-picture on Android and desktop
- Tap **Cast** on supported platforms (AirPlay on macOS/iOS, Chromecast on Android/iOS). Native casting is not wired yet — the player shows a status message (e.g. “AirPlay is not available yet”) instead of failing silently
- Skip intro/recap/credits when IntroDB has data
- Jump to next episode for TV content
- Launch an external player instead of built-in (Settings)

## Tips

- If a stream fails, Forja may auto-try the next source in the list
- Seek preview needs a decodable frame; live or buffering streams may show time only
- Quality shows all detected HLS variants; single-quality or direct streams show the current decoded resolution (e.g. 1080p)
- Long sessions benefit from [torrent cache settings](../settings/torrent-settings.md) when streaming magnets

## Related

- [Torrent playback](torrent-playback.md)
- [Subtitles](subtitles.md)
- [External players](external-players.md)
- [Playback settings](../settings/playback-settings.md)
