# Playback settings

> Play sources, external player, audio, and anime title language.

## What it is

Core playback preferences: which backends **Play** tries on the TMDB details screen, external player, preferred audio and subtitle languages, unsupported codec avoidance, and anime title language.

## How to open it

**Settings → Addons → Playback**

## What you can do

- Player engine, audio, subtitles, auto next/skip, content warnings, background play — see rows under **Settings → Addons → Playback**
- **Play sources** moved: **Direct torrent**, **Stremio**, and **Nuvio** toggles + P2P disclaimer → **Settings → Addons**; pack install → **Settings → Forja Packs** (Forja providers always on)
- On **Android**, choose **Movies & series engine** — **MediaKit (libmpv)** (default) or **ExoPlayer (Media3)** — for Home, Search, Anime, Asian Drama, and **IPTV Movies/Series** (also changeable from the in-player **Player** menu). When the IPTV tab is visible, **IPTV engine** sets **live channels** only (independent of Movies). **Live Matches** defaults to **MediaKit** and remembers its own in-player choice. On **Android TV**, the in-player **Player** menu only lists those two engines (no external apps)
- Set **Preferred audio language**
- Set **Preferred subtitle language** (default **English**) — in-stream mux subs are tried first, then online/scraped tracks; pick **None** to start with subs off
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **Auto next episode** (on by default) — when an episode finishes, start the next one; also available as the **Auto next** switch in the player Episodes panel top bar
- Toggle **Auto skip intro** (off by default) — when IntroDB has intro/recap timestamps, skip them without tapping Skip; also available in the in-player **Settings** menu
- Toggle **Content warnings** (on by default) — show IMDb parents-guide ratings (nudity, violence, and similar) when a movie or episode starts; also available in the in-player **Settings** menu
- Toggle **Play in background** (desktop and phone only — not shown on Android TV) — keep movies, series, and IPTV playing when Forja leaves the foreground (another app, Home, or a Space switch without PiP). **On by default on desktop**; **off by default on phone** (playback pauses until you return — the app stays in memory for a quick resume). When off, returning to Forja resumes if it was playing when you left. **Android TV always pauses** on Home / app switch and resumes when you return (setting is device-local and not cloud-synced, so desktop “on” cannot flip the TV)
- On **macOS / Windows**: toggle **Auto picture-in-picture** (off by default) — while playing, switching Mission Control Space or a Windows virtual desktop shrinks into PiP automatically. Manual PiP from the player button always works
- Toggle **IPTV programme guide (EPG)** under **Settings → Addons → IPTV** — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Set **IPTV live max quality** under **Settings → Addons → IPTV** — **Auto (full quality)** by default (no downscale). Optional **1080p / 720p / 480p** caps ExoPlayer adaptive live variants only if you choose them
- Set **IPTV live recovery** under **Settings → Addons → IPTV** — **Auto** by default (manages stall for you: Xtream gets stall reopen, Stalker / Forja Live / Stremio keep buffer hold without stall). Upgrade migrates unset / old stall / Stable-buffer to Auto once (Classic left alone). Or pick **Stable — buffer-aware** and optionally **Reopen on buffer stall**, or **Classic — stall timers**. Applies the next time you open the IPTV player
- On **Android TV**, **IPTV match display refresh** is on by default and shown only to **admin** accounts under **Addons → IPTV** — MediaKit only; asks the TV to switch refresh rate to match the channel fps (e.g. 50 Hz for 50 fps). Takes effect the next time you open the IPTV player
- On **Android TV**, **IPTV live buffer** is shown only to **admin** accounts under **Addons → IPTV** — MediaKit only; **Auto (by resolution)** (default) uses HD 15 s / FHD+UHD 20 s with 96 MiB demuxer RAM (4K no longer uses 150 MB — that force-closed some boxes), or pick **15 / 20 / 30 seconds** to force the cushion (30 s is 150 MB). For underrun / RAM experiments — does not fix 50 fps-on-60 Hz judder. Takes effect the next time you open the IPTV player
- Set **Max stream quality** to cap automatic source ranking and HLS Auto start bitrate (**4K** by default; Auto, 1440p, 1080p, 720p, …)
- Choose **Anime title language** — **Romaji** (default), **English**, or **Native** — for Anime hub / details / player titles. Stream matching still searches romaji first, then English, native, and AniList synonyms

Cache reset moved to **Settings → [Data & backup](cache-data.md)** (stream URLs, images, scores, continue watching).

## Tips

- Turning a play source **on** starts its engine for this session (Direct torrent → torrent engine; Nuvio → scraper refresh; Forja → plugins). **Sources** and **Forja Packs** categories are always visible in Settings regardless of nav tabs.
- Play source toggles: white link **Play** / **Sources** use **Direct torrent**, **Stremio**, and **Nuvio** when each is enabled; **Forja** is always on when your platform supports it. The **Sources** panel uses **Forja / Torrents / Stremio / Nuvio** (left to right) for the play sources that apply.
- **Max stream quality** caps which sources the engine prefers when ranking (device probe still applies under Auto). Defaults to **4K** (top ladder rung). HLS Auto also uses that cap for start bitrate — Auto is a mid-high soft ceiling for a faster first frame. Lock a Quality chip in the player to force a specific variant.
- External player is chosen per stream from the in-player **Player** menu on phone and desktop — playback always starts in the built-in player. **Android TV** has no external-app handoff from that menu
- **Movies & series engine** / **IPTV engine** (Android only) are independent — desktop/iOS always use MediaKit; **MediaKit** is the Android default (ExoPlayer is optional); **Live Matches** defaults to **MediaKit** until you pick Exo from the in-player **Player** menu

## Related

- [TMDB details](../movies-tv/tmdb-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [Sources settings](torrent-settings.md)
- [Cache & data](cache-data.md)
- [Anime](../hubs/anime.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
- [Subtitles](../playback/subtitles.md)
