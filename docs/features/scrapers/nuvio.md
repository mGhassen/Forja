# Nuvio scrapers

> Install community scraper manifests for extra stream links in the **Sources** panel (Direct torrent).

## What it is

Nuvio addons are manifest URLs that bundle JavaScript scrapers. Each scraper searches specific sites and returns stream candidates. Install a manifest in Settings, enable individual scrapers, and use them from the **Nuvio** tab in **Sources** on [media details](../movies-tv/media-details.md) (white **Play** / link icon — same panel as Forja torrent search). Provider chips under the **Nuvio** tab start with no scrapers selected — pick the ones you want. Opening **Nuvio** waits until you select providers; use **Load next provider** to run them one at a time.

Nuvio is **not** part of green **Play** webstreaming. Direct links only there; torrent/magnet scrapers (e.g. Torrentio) stay in **Sources** and play through the torrent engine.

## How to open it

1. Enable **Direct torrent** under **Play sources** in **Settings → Playback**
2. Open a title → white **Play** / **Sources** → **Nuvio** tab
3. Or install/manage addons under **Settings → Providers & Addons → Nuvio Addons**

## What you can do

- Paste a Nuvio `manifest.json` URL and install
- See scraper count per addon
- Toggle each scraper on/off without removing the addon
- Remove an entire addon
- In **Sources → Nuvio**, choose scrapers from the provider chips under the tab, fetch them one at a time with **Load next provider**, and play a result (magnets use the local torrent engine; HTTP links play directly)

## Setup

1. Enable **Direct torrent** in **Settings → Playback**
2. Obtain a Nuvio manifest URL (community lists or your own) — the app also ships a bundled catalog virtually when not installed
3. Paste into **Install Nuvio Addon** and tap Install (optional — bundled scrapers work without install)
4. Enable scrapers you want; disable noisy or slow ones

## Tips

- Scraper scripts are cached locally after first use
- Refreshing an addon merges new scrapers while keeping your enabled/disabled choices
- **Webstreaming** (green **Play**) uses VidLink, WebStreamr, Videasy, etc. — not Nuvio
- Playing a Nuvio HTTP link from **Sources** must show video — if only audio starts (or the picture stays black), Forja fails that row so you can pick another instead of sitting on a blank screen

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Playback settings](../settings/playback-settings.md)
- [Scrapers overview](README.md)
