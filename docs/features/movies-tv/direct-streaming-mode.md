# Direct streaming mode

> Open titles with auto-extracted stream links instead of torrent search.

## What it is

**Direct streaming mode** (Settings → Playback) makes every movie/series open on the **streaming details** screen, which auto-searches VidLink, VixSrc, WebStreamr, Nuvio scrapers, and other configured providers.

You can also use webstreaming **without** that global toggle: on the normal **torrent details** screen, open **Sources** → **Webstreaming**, pick a provider, then play from the list.

## How to open it

**Global mode (all titles):**

1. Enable **Direct streaming mode** in Settings → Playback
2. Tap any movie or series from Home, Discover, or Search

**Per title (torrent details):**

1. Open a movie or series (Direct streaming mode off)
2. Tap **Play**, **Download**, or open **Sources**
3. Select the **Webstreaming** tab and choose a provider

## What you can do

- See available stream links grouped by provider
- Pick a link and play in the built-in or external player
- Tap a TV episode on the details page to start playback (same flow as **Play** / **Resume**)
- Mark TV episodes as watched
- **Play** / **Resume**, **Trailer** (when available), **My List**, **Download**, and **⋯** overflow (Trakt / Simkl) — same hero actions as torrent details
- Fall through providers in the order you set in Settings
- While a stream is starting, a right-side roulette cycles through each server as it is checked — ✓ when one works, ✗ when it fails, spinner on the active one (★ on your top-priority server)

## Setup (if needed)

- [Stream providers](../sources/stream-providers.md) — reorder providers in Settings → Playback
- [WebStreamr settings](../scrapers/webstreamr-settings.md) — country sources and extractors
- [Nuvio scrapers](../scrapers/nuvio.md) — install extra scraper manifests

## Tips

- Turn streaming mode off anytime to return to torrent-based details by default
- On torrent details, use **Sources → Webstreaming** for direct links without enabling the global toggle
- Provider order matters — put your most reliable source first

## Related

- [Media details](media-details.md) — torrent-based alternative
- [Stream providers](../sources/stream-providers.md)
- [Playback settings](../settings/playback-settings.md)
