# Playback settings

> Play sources, external player, audio, webstreaming provider order, and anime provider order.

## What it is

Core playback preferences: which backends **Play** tries on the media details screen, external player, preferred audio language, unsupported codec avoidance, webstreaming extractor priority, and anime stream source priority.

## How to open it

**Settings → Playback**

## What you can do

- Enable **Play sources**: direct torrent, Stremio, and webstreaming (all on by default on phone and desktop; **Android TV** fresh install enables **Webstreaming** only — turn on torrent or Stremio in this screen if you want **Sources**)
- On **Android**, choose **Built-in engine** — **ExoPlayer (Media3)** (default) or **MediaKit (libmpv)** — in Settings or from the **Player** button in the playback controls
- Set **Preferred audio language**
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **IPTV programme guide (EPG)** — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Reorder **Source scoring** tables for Films, Series, Anime, and Asian Drama (drag baseline rank; see domain score, ±2 adjustment cap, and effective pre-check order)
- Set **Max stream quality** to cap automatic selection (Auto, 4K, 1080p, 720p, …)

## Tips

- Play source toggles: green **Play** (play icon) uses webstreaming; white link **Play** / **Sources** use torrent + Stremio (see [Webstreaming](../movies-tv/direct-streaming-mode.md)). The **Sources** panel merges torrent and Stremio into one list with an **All / Torrents / Stremio** filter.
- **Source scoring** tables: drag sets your **baseline** order per type. **Domain score** may move a provider at most **±2** positions before checking. **Effective** shows the pre-check order the engine uses. Failed checks in the player Source panel apply persisted reliability memory (sort on next open). The **score badge** shows the configured domain tier; it dims when reliability is low and stays bright for the playing server. Stream quality (codec, resolution, latency) is scored **after** resolve — not shown in settings.
- **Max stream quality** caps what the playback engine picks automatically (device probe still applies under Auto)
- Anime uses the same resolve + Rust scoring pipeline as movies; saved source pin still wins when set
- External player is chosen per stream from the in-player **Player** menu — playback always starts in the built-in player
- **Built-in engine** (Android only) applies when Video Player is **Built-in** — desktop/iOS always use MediaKit

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [Anime](../hubs/anime.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
