# External players

> Hand off the current stream to VLC, mpv, IINA, MX Player, or another app.

## What it is

Playback always starts in Forja’s built-in player. During a stream you can send the resolved URL to an external player installed on your device. That choice applies to the **current stream only** — the next title opens in the built-in player again.

Options vary by platform (e.g. IINA, VLC, and mpv on macOS; MX Player on Android). On desktop, the **Player** menu only lists apps that are actually installed — install mpv with Homebrew (`brew install mpv`) if you want the standalone mpv option; IINA and VLC are detected from `/Applications/`.

## How to open it

While watching (built-in player): **Player** control in the playback bar → pick an external app.

While already handed off: **Change player** on the handoff screen.

## What you can do

- Switch the current stream to an external app (one-time per playback session)
- Re-launch or change external app from the handoff screen
- Return to the built-in player with **Watch in Forja instead**

## Tips

- On macOS **VLC** / standalone **mpv**: direct stream URL + CLI header flags (`--http-referrer`, etc.)
- On macOS **IINA**: Forja runs the stream through the local **hls-proxy** (headers injected server-side), then opens it with `open -a IINA.app <proxy-url>`. App Sandbox blocks direct `iina-cli` exec; the IINA GUI binary also rejects `--mpv-*` CLI flags
- **Android** may still use Forja's local hls-proxy when the player cannot accept headers
- **111477 CDN** direct file links use Forja's seek cache proxy (signed redirects)
- External players receive the same mpv network settings as the built-in player (`tls-verify`, HLS cache, timeouts)
- External players bypass Forja's subtitle UI — use players with their own sub support if needed
- Some DRM or header-protected streams may not work outside Forja's proxy if the local server is unavailable

## Related

- [Playback settings](../settings/playback-settings.md)
- [Player](player.md)
