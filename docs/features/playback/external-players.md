# External players

> Hand off the current stream to VLC, mpv, IINA, MX Player, or another app.

## What it is

Playback always starts in Forja’s built-in player. During a stream you can send the resolved URL to an external player installed on your device. That choice applies to the **current stream only** — the next title opens in the built-in player again.

Options vary by platform (e.g. IINA, VLC, and mpv on macOS; MX Player on Android).

## How to open it

While watching (built-in player): **Player** control in the playback bar → pick an external app.

While already handed off: **Change player** on the handoff screen.

## What you can do

- Switch the current stream to an external app (one-time per playback session)
- Re-launch or change external app from the handoff screen
- Return to the built-in player with **Watch in Forja instead**

## Tips

- On macOS, **IINA** and **VLC** are launched via their bundled CLI binaries so the stream URL is passed correctly
- On desktop, **Referer / User-Agent / Origin** headers are passed as mpv/VLC CLI flags (same approach as before the handoff screen)
- On Android, header-protected streams may be proxied through Forja's local server when the player cannot accept headers
- **111477 CDN** direct file links are proxied through Forja's seek cache server so IINA can follow signed redirects
- External players bypass Forja's subtitle UI — use players with their own sub support if needed
- Some DRM or header-protected streams may not work outside Forja's proxy if the local server is unavailable

## Related

- [Playback settings](../settings/playback-settings.md)
- [Player](player.md)
