# Playback settings

> Play sources, external player, audio, webstreaming provider order, and anime provider order.

## What it is

Core playback preferences: which backends **Play** tries on the media details screen, external player, preferred audio language, unsupported codec avoidance, webstreaming extractor priority, and anime stream source priority.

## How to open it

**Settings → Playback**

## What you can do

- Enable **Play sources**: direct torrent, Stremio, and webstreaming (all on by default)
- Select **External player** (built-in or VLC, mpv, etc.)
- Set **Preferred audio language**
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **IPTV programme guide (EPG)** — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Reorder **Provider order** for webstreaming extractors (drag list)
- Reorder **Anime provider order** for anime stream sources (Megaplay, Vidwish, Miruro pipes, AllAnime, AnimeRealms, adult fallbacks)

## Tips

- Play source toggles: green **Play** (play icon) uses webstreaming; white magnet **Play** / **Sources** use torrent + Stremio (see [Webstreaming](../movies-tv/direct-streaming-mode.md)). The **Sources** panel merges torrent and Stremio into one list with an **All / Torrents / Stremio** filter.
- Provider order is the main lever for web link quality — see [Stream providers](../sources/stream-providers.md)
- Anime provider order controls which working source the anime player prefers after the parallel probe (same idea as film webstreaming order)
- External player bypasses built-in subtitle UI

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [Anime](../hubs/anime.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
