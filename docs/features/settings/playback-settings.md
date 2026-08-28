# Playback settings

> Play sources, external player, audio, and anime title language.

## What it is

Core playback preferences: which backends **Play** tries on the media details screen, external player, preferred audio language, unsupported codec avoidance, and anime title language.

## How to open it

**Settings → Playback**

## What you can do

- Enable **Play sources** (listed with **Forja** first): **Forja** plugins (on by default on phone, desktop, and **Android TV**), then **Direct torrent**, **Stremio**, **Nuvio**, and — for **admin** accounts only — **Webstreaming** sniffing extractors. Fresh installs leave torrent / Stremio / Nuvio / Webstreaming off until you turn them on. On **Android TV**, Direct HTTP Stremio/Nuvio/Forja streams play on the TV; magnets / torrents need a paired desktop under **Settings → LAN** (a dialog explains this if you play P2P while unpaired or the desktop is offline). **Sources**, **WebStreamr**, **Debrid**, **Lists**, and **Data & backup** stay hidden on TV
- The first time you turn on **Direct torrent**, **Stremio**, or **Nuvio**, Forja shows a **P2P streaming** disclaimer with a VPN recommendation at the top (IP visible to peers, you are responsible for what you stream, Forja does not host P2P content). **Forja** plugins are HTTP-only and do **not** require that disclaimer. Cancel leaves that source off. After you tap **I am aware**, Playback shows a clickable **You are aware of P2P streaming** notice **above** Play sources (green check; tap to re-read). The dialog does not appear again on this device unless you open that notice. If those sources were already on, the dialog appears the first time you open **Playback**
- When **Nuvio** is off: **Settings → Nuvio addons** and the **Sources → Nuvio** tab stay hidden
- When **Forja** is off: **Settings → Forja plugins** and the **Sources → Forja** tab stay hidden
- On the **Forja** play-source row: **Auto** checkbox (before the switch; **on by default**) — when checked and **Webstreaming** is off, green **Play** / **Resume** on movies/TV, **Anime**, and **Asian Drama** races enabled Forja HTTP plugins (anime- / drama-tagged sets on those hubs) and opens the first stream. Off = Forja only via **Sources → Forja**. Ignored while **Webstreaming** is on (Anime then races Megaplay / VidNest / …; Asian Drama uses KissKH native)
- **Webstreaming** appears only for **admin** accounts (`is_admin`). When on: green **Play** on movies/TV races sniffing extractors; Anime green **Play** includes **VidLink** sniff; Asian Drama may sniff third-party embeds when KissKh has no direct URL. When off: Anime/Asian Drama green **Play** stay on HTTP/native paths only (same idea as Forja Auto with no host sniff). Also toggle **Simple resolve (experimental)** (on by default) — tries one provider at a time in **Tries** order, filters/probes streams, then opens the player once (old multi-provider race stays when this is off)
- Same admin + Webstreaming gate: **STREAMCRYPTO decrypt** — **WebView (current)** (default) or **Native (Dart)**. Used by the enc=2 player family (Videasy, VidSrc.sbs **4K**, …). Native skips the headless WebView for that decrypt
- On **Android**, choose **Movies & series engine** — **MediaKit (libmpv)** (default) or **ExoPlayer (Media3)** — for Home, Search, Anime, Asian Drama, and **IPTV Movies/Series** (also changeable from the in-player **Player** menu). When the IPTV tab is visible, **IPTV engine** sets **live channels** only (independent of Movies). **Live Matches** defaults to **MediaKit** and remembers its own in-player choice. On **Android TV**, the in-player **Player** menu only lists those two engines (no external apps)
- Set **Preferred audio language**
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **Auto next episode** (on by default) — when an episode finishes, start the next one; also available as the **Auto next** switch in the player Episodes panel top bar
- Toggle **Auto skip intro** (off by default) — when IntroDB has intro/recap timestamps, skip them without tapping Skip; also available in the in-player **Settings** menu
- Toggle **Content warnings** (on by default) — show IMDb parents-guide ratings (nudity, violence, and similar) when a movie or episode starts; also available in the in-player **Settings** menu
- Toggle **Play in background** (desktop and phone only — not shown on Android TV) — keep movies, series, and IPTV playing when Forja leaves the foreground (another app, Home, or a Space switch without PiP). **On by default on desktop**; **off by default on phone** (playback pauses until you return — the app stays in memory for a quick resume). When off, returning to Forja resumes if it was playing when you left. **Android TV always pauses** on Home / app switch and resumes when you return (setting is device-local and not cloud-synced, so desktop “on” cannot flip the TV)
- On **macOS / Windows**: toggle **Auto picture-in-picture** (off by default) — while playing, switching Mission Control Space or a Windows virtual desktop shrinks into PiP automatically. Manual PiP from the player button always works
- Toggle **IPTV programme guide (EPG)** when the IPTV tab is visible — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Set **IPTV live max quality** when the IPTV tab is visible — **Auto (full quality)** by default (no downscale). Optional **1080p / 720p / 480p** caps ExoPlayer adaptive live variants only if you choose them
- Set **IPTV live recovery** when the IPTV tab is visible — **Stable — buffer-aware** by default (only reconnect when the live buffer is empty) or **Classic — stall timers** (reconnect on freeze timers). With Stable selected, **Reopen on buffer stall** is on by default for everyone — reconnects when the picture freezes or Buffering sticks with no playback progress, even if the demuxer still reports cache. Applies the next time you open the IPTV player
- On **Android TV**, **IPTV match display refresh** is on by default and shown only to **admin** accounts — MediaKit only; asks the TV to switch refresh rate to match the channel fps (e.g. 50 Hz for 50 fps). Takes effect the next time you open the IPTV player
- Set **Max stream quality** to cap automatic source ranking and HLS Auto start bitrate (Auto, 4K, 1080p, 720p, …)
- Choose **Anime title language** — **Romaji** (default), **English**, or **Native** — for Anime hub / details / player titles. Stream matching still searches romaji first, then English, native, and AniList synonyms

Cache reset moved to **Settings → [Data & backup](cache-data.md)** (stream URLs, images, scores, continue watching).

## Tips

- Play sources appear only when a **VOD tab** (Home, Search, Anime, Asian Drama, or My List) is visible. Turning a play source **on** starts its engine for this session (Direct torrent → torrent engine; Nuvio → scraper refresh; Forja → plugins; Webstreaming → local stream proxy). Sources left **off** are not loaded at splash, and related Settings tiles (Sources, Nuvio addons, Forja plugins) hide until you turn the source back on here. **WebStreamr**, **Debrid**, and **Lists** Settings stay admin-only
- Play source toggles: green **Play** (play icon) uses **Webstreaming** extractors only (admin); white link **Play** / **Sources** use **Direct torrent**, **Stremio**, **Nuvio**, and **Forja** when each is enabled (see [Webstreaming](../movies-tv/direct-streaming-mode.md)). Fresh installs default to **Forja** + **Auto**. The **Sources** panel uses **Forja / Torrents / Stremio / Nuvio** (left to right) for the play sources you turned on.
- Reorder webstreaming extractors under **Settings → [Sources](torrent-settings.md)** → **Server reliability** (see [Stream providers](../sources/stream-providers.md))
- **Max stream quality** caps which sources the engine prefers when ranking (device probe still applies under Auto). HLS Auto also uses that cap for start bitrate — Auto is a mid-high soft ceiling for a faster first frame; **4K** opens the top ladder rung. Lock a Quality chip in the player to force a specific variant.
- Anime uses the same resolve + Rust scoring pipeline as movies; saved source pin still wins when set. Default Anime **Tries** order starts with Megaplay (AniList + MAL id embeds) before Miruro Cloudflare pipes; **VidLink** (MAL from relations/Jikan) sits after AllAnime — Reset in Server reliability restores that if you customized the list
- External player is chosen per stream from the in-player **Player** menu on phone and desktop — playback always starts in the built-in player. **Android TV** has no external-app handoff from that menu
- **Movies & series engine** / **IPTV engine** (Android only) are independent — desktop/iOS always use MediaKit; **MediaKit** is the Android default (ExoPlayer is optional); **Live Matches** defaults to **MediaKit** until you pick Exo from the in-player **Player** menu

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [Sources settings](torrent-settings.md)
- [Cache & data](cache-data.md)
- [Anime](../hubs/anime.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
