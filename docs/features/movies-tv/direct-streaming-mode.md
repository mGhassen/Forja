# Webstreaming

> Direct stream links from web extractors via the hero green **Play** / **Resume** button.

## What it is

**Webstreaming** is a **play source** on the unified [media details](media-details.md) screen — not a tab in **Sources**. When enabled in **Settings → Playback**, the hero shows the default green **Play** / **Resume** pill with a play icon. It auto-searches extractors in your **Provider order** (VidLink, VixSrc, WebStreamr, Nuvio scrapers, …) and starts playback when one works (loading roulette overlay).

The white **Play** / **Resume** with magnet icon opens **Sources** (torrent / Stremio). The **Sources** panel is only for those backends.

## How to open it

1. Enable **Webstreaming** under **Play sources** in **Settings → Playback**
2. Open any movie or series from Home, Discover, or Search
3. Tap the green **Play** / **Resume** on the hero

## What you can do

- Let green **Play** / **Resume** auto-extract the best working link in provider order
- Fall through extractors in the order you set in Settings
- While a stream is starting, a right-side roulette cycles through each server as it is checked — ✓ when one works, ✗ when it fails, spinner on the active one (★ on your top-priority server)

## Setup (if needed)

- [Stream providers](../sources/stream-providers.md) — reorder extractors in Settings → Playback
- [WebStreamr settings](../scrapers/webstreamr-settings.md) — country sources and extractors
- [Nuvio scrapers](../scrapers/nuvio.md) — install extra scraper manifests

## Tips

- Keep torrent/Stremio enabled for the magnet **Play** / **Sources**; use green **Play** when you want a direct link
- Provider order matters — put your most reliable extractor first

## Related

- [Media details](media-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Stream providers](../sources/stream-providers.md)
