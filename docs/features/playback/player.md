# Player

> One player for movies, series, IPTV, and more — desktop and mobile.

## What it is

Forja routes all video playback through a unified player. Controls use a flat overlay (no glass chrome):

- **Top bar** — back arrow (muted until hover or D-pad focus, then white), centered title, **S# E#** for TV episodes, and **Player**, **Cast**, and **PiP** on the top right (platform-gated)
- **Paused overlay** — show logo, rating/year meta, and synopsis on the left when playback is paused (when TMDB metadata is available)
- **Center actions** — large play/pause and ±10s buttons in the middle while controls are visible; hidden while checking sources or buffering (status roulette takes the center instead)
- **Status roulette** — center-right slide-up indicator when checking sources, switching servers, or buffering (no bottom snackbars)
- **Bottom bar** — full-width seek bar, then play/pause, ±10s, volume, and **current / total** time on the left; **Sources** (torrent search panel when playing a magnet — same as media-details Sources), a flat **Source** control (layers icon + server name + chevron) when web/anime/drama streams are available, episodes (TV), audio, subtitles, quality, settings, and fullscreen on the right. On desktop torrent playback, when **Settings → Torrent stats** is on, a transparent stats card sits bottom-right above the seek bar while controls are visible (download/upload speed, peers, download size/%, ETA). It lifts above Skip Intro / Next Episode when those buttons are showing. Seeders show as — unless indexer metadata is available later — librqbit does not expose a live seeder count.
- **Floating menus** — audio, subtitles, quality, and settings open as compact popup panels anchored to the button you tapped (above or below, depending on space). Nested menus show a **Back** control (muted until hover or D-pad focus, then white) when you drill into a sub-list. Dismiss with the borderless **Close** control (soft circular highlight on hover — no outline box)
- **Episodes / Sources / Source panels** — TV **Episodes**, torrent **Sources** (magnet button), and web **Source** (server picker) open right-side panels. Player **Episodes**, **Sources**, **Source**, and **Filters** use a translucent dark shell (no freeze-frame image; no BackdropFilter over live video). **Filters** docks to the left of Sources. **Source** lists servers with IPTV-style status glyphs (**...** / spinner / dot / play / failed) — tap a server to load its streams in parallel. Episodes include season picker, numbered range chips (**1 - 50**, **51 - 100**, …) when the list is long, episode thumbnails, air date (orange when not yet aired), show backdrop with dim overlay on not-yet-aired thumbnails, runtime, synopsis, and resume progress. Not-yet-aired episodes stay visible but cannot be opened. Close with the borderless **Close** control in the header

Seek bar on desktop supports hover frame preview (timestamp fallback when preview is unavailable). **Source** is one flat bottom-right control showing the active server name; tap it for the grouped list. The player handles torrent streams, direct HLS/MP4 links, debrid URLs, Jellyfin, and hub content.

On **Android**, when **Settings → Playback → Built-in engine** is **ExoPlayer**, the same flat overlay chrome applies (top bar, paused hero, center actions, status roulette, bottom seek bar). Episodes, source picker, audio/subtitle/quality menus, PiP, and torrent playback still require **MediaKit** — those buttons show a hint to switch engines.

On **Android TV** (MediaKit or ExoPlayer), D-pad moves focus between chrome controls instead of remote playback shortcuts. Focus order: **back** and top-right **Player / Cast / PiP**, then the **progress bar**, then the bottom transport row (**play/pause**, ±10s, volume, **Sources**, **Source**, **Episodes**, audio, subtitles, quality, settings, lock), then **Skip Intro** / **Next Episode** when shown. The focused control turns **green** (icon, soft fill, outline). **←/→** on the focused progress bar seeks ±10s; **OK** activates the focused button. Audio, subtitles, quality, settings, and **Source** menus or panels open a D-pad focusable list (**↑/↓** between options, **OK** to pick). When both **AirPlay** and **Chromecast** are available, **Cast** opens the same style of focusable picker panel instead of a touch-only menu. **Subtitle settings** (from the subtitles menu) is a D-pad focusable dialog — sliders nudge with **←/→**, color and font chips and delay buttons are focusable, **Back** closes the dialog first. App **toasts** (top-right status messages) expose focusable **action** and **dismiss** controls on TV. **Episodes**, **Sources**, and **Source** side panels are D-pad focusable (close, season/range chips, list rows). **Back** (remote or the top-left back control) closes an open menu, panel, cast picker, subtitle settings dialog, or toast focus target first; a second **Back** exits the player. Controls stay visible on TV (no auto-hide).

## How to open it

Tap **Play** on any details screen, stream list, IPTV channel, or hub episode.

On desktop, playback opens in a **full-window layer** above the app shell — the left nav rail is hidden until you tap back.

## What you can do

- Play, pause, seek (with hover preview on desktop when supported), and adjust volume
- Double-click the video (desktop) to enter/exit fullscreen — films also support **F** or the fullscreen button; IPTV / Live Matches use the fullscreen button or double-click
- Skip ±10 seconds from the bottom bar or large center controls
- Open **Source** (bottom right) — a right-side panel with server rows and stream lists underneath. In the header, next to **reload**, **Embed** toggles whether headless WebView sniffs load embed URLs inside an iframe (checked) or navigate to them directly (unchecked). Stream rows append a language **flag** when the title includes a flag emoji or a recognizable language (e.g. `🔗 CloudStream Pro from VidSrc 🇩🇪`). Tap an empty server to **check** it; tap a loaded server to **expand/collapse** its streams. Hover a loaded server to show a **reload** icon beside the name (refetches that server only). Each server also shows a **score badge** for **this film, TV episode, or anime episode** (not global; Asian drama not scored). The score is the **net** of two verdicts, not a running tally: a **server** verdict (up **+2** when it extracts streams, **−2** when it fails to resolve) plus a **stream** verdict (**+2** when at least one stream plays/probes OK, **−2** only when every known stream is dead — not on the first miss). So an up server whose streams are all dead nets **+2 − 2 = 0**, an up server with a working stream nets **+4**, and a server that never resolved floors at **0**. A **+/− prefix** shows the last change; re-checking the same title re-evaluates the verdicts instead of drifting. Server dots stay **gray** until that server is playing or you verify a stream; **green** means playing/verified, **red** means failed. **CHECKING SOURCES** / Auto tries servers in order until one works for open. If you **manually** check or pick a server/stream, a fail **stops** — no auto hop. Tap an unloaded server to fetch its streams. Tap a stream to **check** it (playback is not interrupted). Hover a live stream to reveal the **play** arrow and switch; failed streams never show play.
- When you leave the player and press **Play** again for the same movie or episode in the same session, Forja reopens the last working web stream directly on that server — no full provider recheck. If you switched server or quality in the player, that selection is remembered.
- First-time search checks providers one at a time in your settings order until one works; after that, playback stays on the server that worked unless you turn **Auto server** back on in player settings.
- Open **Episodes** from the bottom bar — a right-side panel lists the season’s episodes with thumbnail, title, air date (orange when not yet aired), runtime, and synopsis; switch season from the header when the show has multiple seasons; use numbered range chips beside the season control when there are more than 50 episodes. Picking an aired episode resolves the stream and reloads in-player (you stay in the player); not-yet-aired episodes do not launch playback
- Pick another torrent or Stremio stream from the player **Sources** panel — the panel closes immediately and the CHECKING SOURCES roulette shows while the magnet/stream resolves (same feedback as initial source probing), then playback resumes on the new source. Reopening **Sources** borders the currently playing torrent/stream and scrolls it into view
- Switch **audio**, **subtitles**, and **quality** from dedicated bottom-bar buttons
- Open **Settings** popup for speed, aspect ratio, loop, hardware decode, and subtitle style. On desktop torrent sessions, toggle **Torrent stats** (off by default) to show live download/peer info above the seek bar while controls are visible
- Use picture-in-picture on Android and desktop
- Tap **Cast** on supported platforms (AirPlay on macOS/iOS, Chromecast on Android/iOS). Native casting is not wired yet — the player shows a status message (e.g. “AirPlay is not available yet”) instead of failing silently
- Skip intro/recap/credits when IntroDB has data
- Jump to next episode for TV content
- Launch an external player instead of built-in (Settings)

## Tips

- If a stream fails while **Auto server** is On, Forja tries the next server in order. If you **manually** pinned a server or stream, pick another from **Source** — Forja does **not** auto-hop in that case
- Direct HTTP MP4/MKV/HLS opens use a browser-like User-Agent (and extractor Referer when provided). Pasting the same URL in Chrome is a close match; bare `libmpv` is not
- Seek preview needs a decodable frame; live or buffering streams may show time only
- Quality shows all detected HLS variants; single-quality or direct streams show the current decoded resolution (e.g. 1080p)
- Long sessions benefit from [torrent cache settings](../settings/torrent-settings.md) when streaming magnets

## Related

- [Torrent playback](torrent-playback.md)
- [Subtitles](subtitles.md)
- [External players](external-players.md)
- [Playback settings](../settings/playback-settings.md)
