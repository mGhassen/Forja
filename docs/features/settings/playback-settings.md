# Playback settings

> Play sources, external player, and audio.

## What it is

Core playback preferences: which backends **Play** tries on the TMDB details screen, external player, preferred audio and subtitle languages, and unsupported codec avoidance.

## How to open it

**Settings → Addons → Playback**

## What you can do

- Player engine, audio, subtitles, auto next/skip, content warnings, background play — see rows under **Settings → Addons → Playback**
- **Play sources** moved: **Direct torrent**, **Stremio**, and **Nuvio** toggles + P2P disclaimer → **Settings → Addons**; pack install → **Settings → Forja Packs** (Forja providers always on)
- On **Android**, choose **Movies & series engine** — **ExoPlayer (Media3)** (default) or **MediaKit (libmpv)** — for Home, Search, Anime, Asian Drama, and **IPTV Movies/Series** (also changeable from the in-player **Player** menu). When the IPTV tab is visible, **IPTV engine** sets **live channels** only (independent of Movies). **Live Sports** defaults to **ExoPlayer** and remembers its own in-player choice. On **Android TV**, the in-player **Player** menu only lists those two engines (no external apps). Streams with a Widevine license (e.g. Shahid) always use ExoPlayer on Android.
- Set **Preferred audio language**
- Set **Preferred subtitle language** (default **English**). In-stream mux subs are tried first, then online tracks. Pick **None** to start with subs off
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **Auto next episode** (on by default). When an episode finishes, start the next one. Also available as **Auto next** in the player Episodes panel
- Toggle **Auto skip intro** (off by default). Skips intro/recap when timestamps are available. Also available in the in-player **Settings** menu
- Toggle **Content warnings** (on by default). Shows IMDb content ratings when playback starts. Also available in the in-player **Settings** menu
- Toggle **Play in background** (desktop and phone only; not shown on Android TV). Keeps movies, series, and IPTV playing when Forja is in the background. **On by default on desktop**; **off by default on phone**. When off, returning to Forja resumes if it was playing. **Android TV always pauses** on Home / app switch (device-local; not cloud-synced)
- On **Android TV**: toggle **Remote click sounds** (on by default). System clicks when you move D-pad focus or press OK. Silent while a video is playing. Device-local (not cloud-synced)
- On **macOS / Windows**: toggle **Auto picture-in-picture**. While playing, switching Space or a Windows virtual desktop enters PiP. The player PiP button always works
- On **macOS / Windows** (desktop profile only — **not** Android TV or phone): the player top-right **In-app mini player** button always demotes to a corner mini **inside** Forja. Toggle **Escape to mini player** (**off** by default) so Escape (after hide chrome) demotes instead of arming leave. Not the same as picture-in-picture. See [In-app mini player](../playback/in-app-mini-player.md)
- Toggle **IPTV programme guide (EPG)** under **Settings → Addons → IPTV** (only while the IPTV pack is installed). Shows NOW / NEXT in the IPTV player and browser (on by default)
- Set **IPTV live max quality** under **Settings → Addons → IPTV**. **Auto** uses full portal quality. Optional **1080p / 720p / 480p** caps ExoPlayer adaptive live variants
- Set **IPTV live recovery** under **Settings → Addons → IPTV** when the **IPTV engine** is **ExoPlayer** (Android). **Auto** / **Stable** / **Classic** only affect Exo reconnect. **MediaKit** ignores this setting (ffmpeg reconnect + silent reopen on underrun or hardware-decode death)
- On **Android TV**, **IPTV match display refresh** is on by default and shown only to **admin** accounts under **Addons → IPTV**. MediaKit only; matches TV refresh rate to channel fps. Applies the next time you open the IPTV player
- On **Android TV**, **IPTV live buffer** is shown only to **admin** accounts under **Addons → IPTV**. MediaKit only; **Auto** uses a **30s** demuxer window (same on phone/desktop and TV), or pick **15 / 20 / 30 seconds**. Helps underruns, not frame judder. Applies the next time you open the IPTV player
- Portal URL / username / password for the active Xtream portal are pack settings on the same **Addons → IPTV** page
- Set **Max stream quality** to limit Auto ranking and HLS start bitrate (**4K** by default; Auto, 1440p, 1080p, 720p, …)

Cache reset moved to **Settings → [Data & backup](cache-data.md)** (stream URLs, images, scores, continue watching).

## Tips

- Anime title language lives under **Settings → Addons → Anime** when the Anime pack is installed — see [Anime](../hubs/anime.md)
- Turning a play source **on** starts its engine for this session (Direct torrent → torrent engine; Nuvio → scraper refresh; Forja → plugins). **Sources** and **Forja Packs** categories are always visible in Settings regardless of nav tabs.
- Play source toggles: white link **Play** / **Sources** use **Direct torrent**, **Stremio**, and **Nuvio** when each is enabled; **Forja** is always on when your platform supports it. The **Sources** panel uses **Forja / Torrents / Stremio / Nuvio** (left to right) for the play sources that apply.
- **Green Play** (hero play icon) races Forja providers. Optional preferred list under **Addons** / **Forja Packs** → **Green Play** (search → add). Empty preferred = all enabled Forja plugins. Sources chips stay panel-only.
- **Max stream quality** caps which sources the engine prefers when ranking (device probe still applies under Auto). Defaults to **4K** (top ladder rung). HLS Auto also uses that cap for start bitrate — Auto is a mid-high soft ceiling for a faster first frame. Lock a Quality chip in the player to force a specific variant.
- External player is chosen per stream from the in-player **Player** menu on phone and desktop — playback always starts in the built-in player. **Android TV** has no external-app handoff from that menu
- **Movies & series engine** / **IPTV engine** (Android only) are independent — desktop/iOS always use MediaKit; **ExoPlayer** is the Android default (MediaKit is optional); **Live Sports** defaults to **ExoPlayer** until you pick MediaKit from the in-player **Player** menu

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
