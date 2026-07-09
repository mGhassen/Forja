# Webstreaming

> Direct stream links from web extractors on the media details screen.

## What it is

**Webstreaming** is a **play source** on the unified [media details](media-details.md) screen — not a separate screen or global mode. When enabled in **Settings → Playback**, **Play** can use VidLink, VixSrc, WebStreamr, Nuvio scrapers, and other configured extractors.

If webstreaming is the **only** enabled play source, **Play** auto-searches extractors in your **Provider order** and starts playback when one works (with the loading roulette overlay).

You can also pick links manually: **Sources** → **Webstreaming** → choose a provider → play from the list.

## How to open it

1. Enable **Webstreaming** under **Play sources** in **Settings → Playback**
2. Open any movie or series from Home, Discover, or Search
3. Tap **Play**, or open **Sources** → **Webstreaming**

## What you can do

- See available stream links grouped by provider
- Pick a link and play in the built-in or external player
- Let **Play** auto-extract when webstreaming is your only source
- Fall through extractors in the order you set in Settings
- While a stream is starting, a right-side roulette cycles through each server as it is checked — ✓ when one works, ✗ when it fails, spinner on the active one (★ on your top-priority server)

## Setup (if needed)

- [Stream providers](../sources/stream-providers.md) — reorder extractors in Settings → Playback
- [WebStreamr settings](../scrapers/webstreamr-settings.md) — country sources and extractors
- [Nuvio scrapers](../scrapers/nuvio.md) — install extra scraper manifests

## Tips

- Combine play sources (torrent + Stremio + webstreaming) to let **Play** try each backend in order
- Provider order matters — put your most reliable extractor first

## Related

- [Media details](media-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Stream providers](../sources/stream-providers.md)
