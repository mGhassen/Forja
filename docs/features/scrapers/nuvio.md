# Nuvio scrapers

> Install community scraper manifests for extra stream links in the **Sources** panel (**Nuvio** play source).

## What it is

Nuvio addons are manifest URLs that bundle JavaScript scrapers. Each scraper searches specific sites and returns stream candidates. Manage them in Settings, enable individual scrapers, and use them from the **Nuvio** tab in **Sources** on [TMDB details](../movies-tv/tmdb-details.md) (white **Play** / link icon — same panel as Forja torrent search). Provider chips under the **Nuvio** tab remember your selection on this device — tap a scraper to select it and load its sources; tap a fetched scraper again to deselect and clear that scraper’s rows. **All** loads every enabled scraper but only highlights the All chip — tap one scraper to filter to it; without All, multi-select toggles as before. Opening Nuvio with **All** (or several chips) selected keeps up to 10 scrapers in flight (5 on TV) until every selected one has been tried. Tap a scraper chip to add it to the in-flight search (does not stop the others). First open (no saved chips yet) starts with every enabled scraper selected.

Turn on **Nuvio** under **Settings → Addons**, then install at least one Nuvio manifest (for example the community All-in-One catalog). Each addon row has a switch to enable or disable every scraper in that pack; expand the row to toggle scrapers one by one.

Nuvio is **not** part of green **Play** webstreaming. Direct links only there; torrent/magnet scrapers (e.g. Torrentio) stay in **Sources** and play through the torrent engine.

## How to open it

1. Enable **Nuvio** in **Settings → Addons**
2. Open a title → white **Play** / **Sources** → **Nuvio** tab (tab stays visible while Nuvio is on; install scrapers if the list is empty)
3. Or manage manifests under **Settings → Addons → Nuvio**, or on the web portal under **Profile → Addons → Nuvio** (hidden when Nuvio is off)

## What you can do

- Paste a Nuvio `manifest.json` URL and install
- Toggle an addon’s switch to enable or disable all of its scrapers at once
- Expand an addon and toggle each scraper on/off without removing the addon
- Remove a user-installed addon (trash → Yes / No confirm)
- In **Sources → Nuvio**, tap **All** to load every scraper (only All stays highlighted; tap **All** again to clear), or from All tap one scraper to filter to it; without All, tap scraper chips to multi-select (tap a fetched scraper again to remove their sources); the selection is remembered on this device across titles. Opening Nuvio with **All** selected keeps up to 10 scrapers in flight (5 on TV) until every selected one has been tried; a scraper chip shows the same animated **…** as the Nuvio tab while it is still checking; tap a chip to add it to the search (does **not** stop scrapers still running). Play a result (HTTP links play directly; magnets use the local torrent engine, or a paired desktop on Android TV)

## Setup

1. Enable **Nuvio** in **Settings → Addons**
2. Open **Settings → Addons → Nuvio** and paste a Nuvio manifest URL, then Install
3. Use the addon switch to enable/disable all scrapers, or expand and toggle individually — disable noisy or slow ones

## Tips

- Scraper scripts are cached locally after first use
- Refreshing an addon merges new scrapers while keeping your enabled/disabled choices
- **Webstreaming** (green **Play**) uses VidLink, Videasy, engine providers, etc. — not Nuvio
- Playing a Nuvio HTTP link from **Sources** must show video — if only audio starts (or the picture stays black), Forja fails that row so you can pick another instead of sitting on a blank screen
- **Cancel**, leave the title, or switch tabs while scrapers are still checking stops work without disposing the JS heap mid-evaluate (avoids a macOS crash). Sources → Forja uses the same cancel contract.
- HubCloud / 4kHdHub Drive proxies (`*.workers.dev` with `::` in the path) are probed before they appear. Google Drive **download quota exceeded** files are omitted — they cannot play until Drive resets that file (~24h)
- Scrapers that AES-decrypt their API (Castle and similar) run on Forja the same as on Nuvio
- On Android (QuickJS), scrapers run one at a time on the shared JS runtime so Sources → Nuvio matches desktop instead of returning empty under parallel load

## Related

- [TMDB details](../movies-tv/tmdb-details.md)
- [Webstreaming](../movies-tv/direct-streaming-mode.md)
- [Playback settings](../settings/playback-settings.md)
- [Scrapers overview](README.md)
