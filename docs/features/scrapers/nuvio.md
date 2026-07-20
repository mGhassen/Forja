# Nuvio scrapers

> Install community scraper manifests for extra stream links in the **Sources** panel (**Nuvio** play source).

## What it is

Nuvio addons are manifest URLs that bundle JavaScript scrapers. Each scraper searches specific sites and returns stream candidates. Manage them in Settings, enable individual scrapers, and use them from the **Nuvio** tab in **Sources** on [media details](../movies-tv/media-details.md) (white **Play** / link icon — same panel as Forja torrent search). Provider chips under the **Nuvio** tab remember your selection on this device — tap a scraper to select it and load its sources immediately; tap again to deselect and clear that scraper’s rows. Selecting more scrapers loads each newly selected one lazily (one at a time).

Forja ships a **built-in** All-in-One Nuvio catalog. It appears in **Settings → Nuvio addons** (same scrapers as **Sources → Nuvio**). You can toggle scrapers on or off; the built-in addon cannot be removed.

Nuvio is **not** part of green **Play** webstreaming. Direct links only there; torrent/magnet scrapers (e.g. Torrentio) stay in **Sources** and play through the torrent engine.

## How to open it

1. Enable **Nuvio** under **Play sources** in **Settings → Playback**
2. Open a title → white **Play** / **Sources** → **Nuvio** tab
3. Or manage addons under **Settings → Providers & Addons → Nuvio Addons** (hidden when Nuvio play source is off), or on the web portal under **Profile → Nuvio addons** (also hidden when Nuvio play source is off)

## What you can do

- See the built-in catalog and any manifests you install
- Paste a Nuvio `manifest.json` URL and install more
- Toggle each scraper on/off without removing the addon
- Remove a user-installed addon (not the built-in one)
- In **Sources → Nuvio**, tap **All** to select every scraper, or tap individual scraper chips (tap again to remove their sources); the selection is remembered on this device across titles, and play a result (magnets use the local torrent engine; HTTP links play directly)

## Setup

1. Enable **Nuvio** in **Settings → Playback**
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
