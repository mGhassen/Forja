# Webstreaming

> Direct stream links from web extractors via the hero green **Play** / **Resume** button.

## What it is

**Webstreaming** is a **play source** on the unified [TMDB details](tmdb-details.md) screen — not a tab in **Sources**. It is available to **admin** accounts only. When enabled in **Settings → Playback**, the hero shows the default green **Play** / **Resume** pill with a play icon. It auto-searches extractors in your **Provider order** (VidLink, VixSrc, Videasy, Forja engine plugins, …) and starts playback when one works (loading roulette overlay).

The white **Play** / **Resume** with link icon opens **Sources** (Direct torrent providers, **Nuvio**, **Forja**, Stremio). The **Sources** panel is not used for webstreaming.

## How to open it

1. Enable **Webstreaming** under **Play sources** in **Settings → Playback** (admin accounts only)
2. Open any movie or series from Home, Discover, or Search
3. Tap the green **Play** / **Resume** on the hero

## What you can do

- Let green **Play** / **Resume** auto-extract the best working link in provider order
- Fall through extractors in the order you set in Settings
- While servers are checking, the loading screen shows `N / M CHECKED · K UP` progress. For series it also shows the selected episode (`S02E05`) under the status line. Next to **Cancel**, tap the layers icon to open the **server list** — live Waiting / Checking / Up / Down status for each provider. Tap a waiting or down server to **check it manually** (stops Auto order and resolves that provider only)
- Before mpv opens a link, Forja HTTP-probes it (every built-in provider) — dead CDNs fail fast and Auto continues to the next server
- **Simple resolve** (default): walks **Tries** one server at a time with real budgets — engine HTTP plugins and embed sniffs get full per-provider timeouts so slower paths are not cut off while faster embeds alone “work”
- A server only counts as streaming when video actually opens (not when extract alone returns a URL)
- Leave the player and tap green **Play** again on the same title (or same TV episode) — Forja reuses the last **confirmed** webstreaming extract (session/disk cache, ~25 minutes) instead of re-racing providers. Stremio Direct / torrent / Amri sessions are not stored in that cache. Cached or Continue Watching links are probed before open; expired CDN tokens and dead segments drop the cache and re-resolve like first Play
- In the player **Servers** menu, tapping a server reuses cache only when that provider already has a cached extract for this title/episode; otherwise it runs a fresh resolve for that server.

## Setup (if needed)

- [Stream providers](../sources/stream-providers.md) — reorder webstreaming extractors in Settings → Playback
- [Nuvio scrapers](../scrapers/nuvio.md) — extra scrapers in **Sources** (Nuvio play source), not webstreaming

## Tips

- Keep **Direct torrent** / **Stremio** / **Nuvio** / **Forja** enabled for **Sources**; use green **Play** when you want a direct HTTP/HLS link only
- Provider order matters — put your most reliable extractor first

## Related

- [TMDB details](tmdb-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Stream providers](../sources/stream-providers.md)
