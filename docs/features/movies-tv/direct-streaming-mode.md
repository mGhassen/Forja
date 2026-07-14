# Webstreaming

> Direct stream links from web extractors via the hero green **Play** / **Resume** button.

## What it is

**Webstreaming** is a **play source** on the unified [media details](media-details.md) screen — not a tab in **Sources**. When enabled in **Settings → Playback**, the hero shows the default green **Play** / **Resume** pill with a play icon. It auto-searches extractors in your **Provider order** (VidLink, VixSrc, WebStreamr, Videasy, …) and starts playback when one works (loading roulette overlay).

The white **Play** / **Resume** with link icon opens **Sources** (Direct torrent / Forja, **Nuvio**, Stremio). The **Sources** panel is not used for webstreaming.

## How to open it

1. Enable **Webstreaming** under **Play sources** in **Settings → Playback**
2. Open any movie or series from Home, Discover, or Search
3. Tap the green **Play** / **Resume** on the hero

## What you can do

- Let green **Play** / **Resume** auto-extract the best working link in provider order
- Fall through extractors in the order you set in Settings
- While a stream is starting, a right-side roulette cycles through each server as it is checked — ✓ when one works, ✗ when it fails, spinner on the active one (★ on your top-priority server)
- Leave the player and tap green **Play** again on the same title (or same TV episode) — Forja reuses the last working extract (session/disk cache) instead of re-racing providers. If that link is dead, it drops the cache and runs the roulette again.
- In the player **Servers** menu, tapping a server reuses cache only when that provider already has a cached extract for this title/episode; otherwise it runs a fresh resolve for that server.

## Setup (if needed)

- [Stream providers](../sources/stream-providers.md) — reorder webstreaming extractors in Settings → Playback
- [WebStreamr settings](../scrapers/webstreamr-settings.md) — country sources and extractors
- [Nuvio scrapers](../scrapers/nuvio.md) — extra scrapers in **Sources** (Direct torrent), not webstreaming

## Tips

- Keep **Direct torrent** / Stremio enabled for magnet **Sources**; use green **Play** when you want a direct HTTP/HLS link only
- Provider order matters — put your most reliable extractor first

## Related

- [Media details](media-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Stream providers](../sources/stream-providers.md)
