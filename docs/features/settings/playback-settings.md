# Playback settings

> Direct streaming mode, external player, audio, and provider order.

## What it is

Core playback preferences: whether to default to torrent or streaming details, which external player to use, preferred audio language, unsupported codec avoidance, and stream provider priority order.

## How to open it

**Settings → Playback**

## What you can do

- Toggle **Direct streaming mode** (streaming details vs torrent details)
- When torrent mode is on, enable **Play sources**: direct torrent, Stremio, and webstreaming (all on by default)
- Select **External player** (built-in or VLC, mpv, etc.)
- Set **Preferred audio language**
- Toggle **Avoid unsupported audio** (Atmos, TrueHD, 7.1)
- Toggle **IPTV programme guide (EPG)** — load and show NOW / NEXT guide data in IPTV player and browser (on by default)
- Reorder **Stream providers** (drag list)

## Tips

- Streaming mode + provider order is the main lever for link quality — see [Stream providers](../sources/stream-providers.md)
- Play source toggles control which backends hero/details **Play** tries, in order: torrent → Stremio → webstreaming. The **Sources** panel shows only the enabled source types.
- External player bypasses built-in subtitle UI

## Related

- [Direct streaming mode](../movies-tv/direct-streaming-mode.md)
- [Stream providers](../sources/stream-providers.md)
- [External players](../playback/external-players.md)
- [Audio tracks](../playback/audio-tracks.md)
