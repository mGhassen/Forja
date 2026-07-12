# External players

> Hand off playback to VLC, mpv, MX Player, or another app you prefer.

## What it is

Instead of the built-in media_kit player, you can send stream URLs to external players installed on your device. Options vary by platform (e.g. IINA, VLC, and mpv on macOS; MX Player on Android).

## How to open it

**Settings → Playback → External player** — choose Built-in or a listed external player.

## What you can do

- Select default player for new playback sessions
- Launch streams in the external app with the resolved URL

## Tips

- On macOS, **IINA** and **VLC** are launched via their bundled CLI binaries so the stream URL is passed correctly
- Streams that need **Referer / User-Agent / Origin** headers are proxied through Forja's local server before opening in an external player
- External players bypass Forja's subtitle UI — use players with their own sub support if needed
- Some DRM or header-protected streams may not work outside Forja's proxy if the local server is unavailable

## Related

- [Playback settings](../settings/playback-settings.md)
- [Player](player.md)
