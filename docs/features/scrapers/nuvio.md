# Nuvio scrapers

> Install community scraper manifests for extra stream links in the **Sources** panel (Direct torrent).

## What it is

Nuvio addons are manifest URLs that bundle JavaScript scrapers. Each scraper searches specific sites and returns stream candidates. Manage them in Settings, enable individual scrapers, and use them from the **Nuvio** tab in **Sources** on [media details](../movies-tv/media-details.md) (white **Play** / link icon — same panel as Forja torrent search). Provider chips under the **Nuvio** tab start with no scrapers selected — pick the ones you want. Opening **Nuvio** waits until you select providers; use **Load next provider** to run them one at a time.

Forja ships a **built-in** All-in-One Nuvio catalog. It appears in **Settings → Nuvio addons** (same scrapers as **Sources → Nuvio**). You can toggle scrapers on or off; the built-in addon cannot be removed.

Nuvio is **not** part of green **Play** webstreaming. Direct links only there; torrent/magnet scrapers (e.g. Torrentio) stay in **Sources** and play through the torrent engine.

## How to open it

1. Enable **Direct torrent** under **Play sources** in **Settings → Playback**
2. Open a title → white **Play** / **Sources** → **Nuvio** tab
3. Or manage addons under **Settings → Providers & Addons → Nuvio Addons**

## What you can do

- See the built-in catalog and any manifests you install
- Paste a Nuvio `manifest.json` URL and install more
- Toggle each scraper on/off without removing the addon
- Remove a user-installed addon (not the built-in one)
- In **Sources → Nuvio**, choose scrapers from the provider chips under the tab, fetch them one at a time with **Load next provider**, and play a result (magnets use the local torrent engine; HTTP links play directly)

## Setup

1. Enable **Direct torrent** in **Settings → Playback**
2. Open **Settings → Providers & Addons → Nuvio Addons** — the built-in catalog is already listed
3. Optionally paste another Nuvio manifest URL and tap Install
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
