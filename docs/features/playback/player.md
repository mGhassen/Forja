# Player

> One player for movies, series, IPTV, and more — desktop and mobile.

## What it is

Forja routes all video playback through a unified player. Controls use a flat overlay (no glass chrome):

- **Top bar** — back arrow, centered title, **S# E#** for TV episodes, and **Player**, **Cast**, and **PiP** on the top right (platform-gated)
- **Paused overlay** — show logo, rating/year meta, and synopsis on the left when playback is paused (when TMDB metadata is available)
- **Center actions** — large play/pause and ±10s buttons in the middle while controls are visible; hidden while checking sources or buffering (status roulette takes the center instead)
- **Status roulette** — center-right slide-up indicator when checking sources, switching servers, buffering, or auto-fallback (no bottom snackbars)
- **Bottom bar** — full-width seek bar, then play/pause, ±10s, volume, and **current / total** time on the left; **Sources** (torrent search panel when playing a magnet — same as media-details Sources), a flat **Source** control (layers icon + server name + chevron) when web/anime/drama streams are available, episodes (TV), audio, subtitles, quality, settings, and fullscreen on the right. On desktop torrent playback, when **Settings → Torrent stats** is on, a transparent stats card sits bottom-right above the seek bar while controls are visible (download/upload speed, peers, download size/%, ETA). It lifts above Skip Intro / Next Episode when those buttons are showing. Seeders show as — unless indexer metadata is available later — librqbit does not expose a live seeder count.
- **Floating menus** — audio, subtitles, quality, and settings open as compact popup panels anchored to the button you tapped (above or below, depending on space). Dismiss with the borderless **Close** control (soft circular highlight on hover — no outline box)
- **Episodes / Sources / Source panels** — TV **Episodes**, torrent **Sources** (magnet button), and web **Source** (server picker) open right-side panels. Player **Episodes**, **Sources**, **Source**, and **Filters** use a translucent dark shell (no freeze-frame image; no BackdropFilter over live video). **Filters** docks to the left of Sources. **Source** is a flat grouped list: server name as a text header, stream rows underneath with a type column (HLS / MP4) — no cards or nested boxes. Tap **Load streams** on a server to fetch and list its streams in the panel without closing it. Episodes include season picker, numbered range chips (**1 - 50**, **51 - 100**, …) when the list is long, episode thumbnails, runtime, synopsis, and resume progress. Close with the borderless **Close** control in the header

Seek bar on desktop supports hover frame preview (timestamp fallback when preview is unavailable). **Source** is one flat bottom-right control showing the active server name; tap it for the grouped list. The player handles torrent streams, direct HLS/MP4 links, debrid URLs, Jellyfin, and hub content.

## How to open it

Tap **Play** on any details screen, stream list, IPTV channel, or hub episode.

On desktop, playback opens in a **full-window layer** above the app shell — the left nav rail is hidden until you tap back.

## What you can do

- Play, pause, seek (with hover preview on desktop when supported), and adjust volume
- Double-click the video (desktop) to enter/exit fullscreen — films also support **F** or the fullscreen button; IPTV / Live Matches use the fullscreen button or double-click
- Skip ±10 seconds from the bottom bar or large center controls
- Open **Source** (bottom right) — a right-side panel with server name headers and stream rows underneath (HLS / MP4 type column). The current server and its playing stream are listed first. Tap **Load streams** on an unloaded server to fetch its streams in the panel; picking a stream closes the panel and starts playback. While **CHECKING SOURCES** runs, other servers show **Checking…** or **Unavailable** to match the status roulette; the panel stays open and tappable — picking another server cancels the in-flight check.
- When you leave the player and press **Play** again for the same movie or episode in the same session, Forja reopens the last working web stream directly on that server — no full provider recheck. If you switched server or quality in the player, that selection is remembered.
- First-time search checks providers one at a time in your settings order until one works; after that, playback stays on the server that worked unless you turn **Auto server** back on in player settings.
- Open **Episodes** from the bottom bar — a right-side panel lists the season’s episodes with thumbnail, title, runtime, and synopsis; switch season from the header when the show has multiple seasons; use numbered range chips beside the season control when there are more than 50 episodes. Picking another episode resolves the stream and reloads in-player (you stay in the player)
- Pick another torrent or Stremio stream from the player **Sources** panel — the panel closes immediately and the CHECKING SOURCES roulette shows while the magnet/stream resolves (same feedback as initial source probing), then playback resumes on the new source. Reopening **Sources** borders the currently playing torrent/stream and scrolls it into view
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
