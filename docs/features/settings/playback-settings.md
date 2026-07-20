# Playback settings

> Play sources, external player, audio, webstreaming provider order, and anime provider order.

## What it is

Core playback preferences: which backends **Play** tries on the media details screen, external player, preferred audio language, unsupported codec avoidance, webstreaming extractor priority, and anime stream source priority.

## How to open it

**Settings → Playback**

## What you can do

- Enable **Play sources**: **Direct torrent** (Forja / Jackett / Prowlarr in **Sources**), **Stremio**, **Nuvio**, and **Webstreaming** (torrent / Stremio / Nuvio / webstreaming on by default on phone and desktop; **Android TV** fresh install enables **Webstreaming** only — turn on the others here if you want **Sources**)
- When **Nuvio** is off: **Settings → Nuvio addons** and the **Sources → Nuvio** tab stay hidden
- When **Webstreaming** is on and the signed-in account is an **admin**: toggle **Simple resolve (experimental)** (on by default) — tries one provider at a time, filters/probes streams, then opens the player once (old multi-provider race stays when this is off). Non-admin accounts do not see this row
- On **Android**, choose **Built-in engine** — **ExoPlayer (Media3)** (default) or **MediaKit (libmpv)** — in Settings or from the **Player** button in the playback controls
- Set **Preferred audio language**
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **Auto next episode** (on by default) — when an episode finishes, start the next one; also available as the **Auto next** switch in the player Episodes panel top bar
- Toggle **Auto skip intro** (off by default) — when IntroDB has intro/recap timestamps, skip them without tapping Skip; also available in the in-player **Settings** menu
- Toggle **IPTV programme guide (EPG)** when the IPTV tab is visible — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Reorder **Server reliability** when **Webstreaming** is on — Movies, Series, and Anime: drag preference; **Score** is live reliability; **Tries** is Auto check order. Asian Drama currently keeps one KissKH host enabled and shows the others **On hold**
- Set **Max stream quality** to cap automatic selection (Auto, 4K, 1080p, 720p, …)

Cache reset moved to **Settings → [Data & backup](cache-data.md)** (stream URLs, images, scores, continue watching).

## Tips

- Play sources appear only when a **VOD tab** (Home, Search, Anime, Asian Drama, or My List) is visible. Turning a play source **on** starts its engine for this session (Direct torrent → torrent engine; Nuvio → scraper refresh; Webstreaming → local stream proxy). Sources left **off** are not loaded at splash, and related Settings tiles (Sources, Debrid, WebStreamr, Nuvio addons) hide until you turn the source back on here
- Play source toggles: green **Play** (play icon) uses **Webstreaming** extractors only; white link **Play** / **Sources** use **Direct torrent**, **Stremio**, and **Nuvio** when each is enabled (see [Webstreaming](../movies-tv/direct-streaming-mode.md)). The **Sources** panel uses **Torrents / Stremio / Nuvio** for the play sources you turned on.
- **Server reliability**: tabs for Movies / Series / Anime / Asian Drama (one list at a time). Drag to prefer a server where ordering is enabled. **Score** rises when a check **finishes** with linked server+stream outcomes (extract+stream OK → +4; extract OK but streams dead → net 0; never below **0**). Cancel / extract-only does not add a lone +2. **Tries** (1st, 2nd, …) is the order Auto tries them. Asian Drama enables only `kisskh.nl`; `.co`, `.ovh`, `.la`, and `.do` remain visible as **On hold** and cannot be reordered, preventing automatic mirror checks from triggering KissKH's shared-IP rate limit. In the player Source panel, the **badge number** is the same Score; **+/−** prefixes are this film/episode only (see [Stream providers](../sources/stream-providers.md)). Stream quality (codec, resolution, latency) is scored **after** resolve.
- **Max stream quality** caps what the playback engine picks automatically (device probe still applies under Auto)
- Anime uses the same resolve + Rust scoring pipeline as movies; saved source pin still wins when set. Default Anime **Tries** order starts with Megaplay / Vidwish (direct embed) before Miruro Cloudflare pipes — Reset in Server reliability restores that if you customized the list
- External player is chosen per stream from the in-player **Player** menu — playback always starts in the built-in player
- **Built-in engine** (Android only) applies when Video Player is **Built-in** — desktop/iOS always use MediaKit

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [Cache & data](cache-data.md)
- [Anime](../hubs/anime.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
