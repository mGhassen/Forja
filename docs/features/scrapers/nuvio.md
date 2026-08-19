# Nuvio scrapers

> Install community scraper manifests for extra stream links in the **Sources** panel (**Nuvio** play source).

## What it is

Nuvio addons are manifest URLs that bundle JavaScript scrapers. Each scraper searches specific sites and returns stream candidates. Manage them in Settings, enable individual scrapers, and use them from the **Nuvio** tab in **Sources** on [media details](../movies-tv/media-details.md) (white **Play** / link icon — same panel as Forja torrent search). Provider chips under the **Nuvio** tab remember your selection on this device — tap a scraper to select it and load its sources; tap a fetched scraper again to deselect and clear that scraper’s rows. Opening Nuvio with **All** (or several chips) selected loads those scrapers in groups of 5 until every selected one has been tried. Tap a single scraper chip to load just that one (stops a scraper still running; tap it again to continue). **Settings → Sources → Nuvio → Select All by default** (on by default) starts with every enabled scraper selected; off starts with none.

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
- Remove a user-installed addon (trash → Yes / No confirm; not the built-in one)
- In **Sources → Nuvio**, tap **All** to select every scraper (tap **All** again to deselect them all), or tap individual scraper chips (tap a fetched scraper again to remove their sources); the selection is remembered on this device across titles unless you change **Select All by default** in Settings. Opening Nuvio with **All** selected loads scrapers in groups of 5 until every selected one has been tried; a scraper chip shows the same animated **…** as the Nuvio tab while it is still checking; tap a single chip to load just that one (that **stops** a scraper still running; tap it again to continue). Play a result (HTTP links play directly; magnets use the local torrent engine, or a paired desktop on Android TV)

## Setup

1. Enable **Nuvio** in **Settings → Playback**
2. Open **Settings → Sources → Nuvio addons** — the built-in catalog is already listed
3. Optionally paste another Nuvio manifest URL and tap Install
4. Enable scrapers you want; disable noisy or slow ones
5. **Select All by default** (on) opens Sources → Nuvio with every enabled scraper selected; off starts with none

## Tips

- Scraper scripts are cached locally after first use
- Refreshing an addon merges new scrapers while keeping your enabled/disabled choices
- **Webstreaming** (green **Play**) uses VidLink, WebStreamr, Videasy, etc. — not Nuvio
- Playing a Nuvio HTTP link from **Sources** must show video — if only audio starts (or the picture stays black), Forja fails that row so you can pick another instead of sitting on a blank screen
- HubCloud / 4kHdHub Drive proxies (`*.workers.dev` with `::` in the path) are probed before they appear. Google Drive **download quota exceeded** files are omitted — they cannot play until Drive resets that file (~24h)
- Scrapers that AES-decrypt their API (Castle and similar) run on Forja the same as on Nuvio
- On Android (QuickJS), scrapers run one at a time on the shared JS runtime so Sources → Nuvio matches desktop instead of returning empty under parallel load

## Related

- [Media details](../movies-tv/media-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Playback settings](../settings/playback-settings.md)
- [Scrapers overview](README.md)
