# Navigation

> Move between movies, live TV, music, reading, and more from the main tab bar.

## What it is

Forja uses a tab-based shell. **Default tabs:** Home, Search, My List, and Settings. On desktop you get a narrow side rail (grey icons, Netflix-style underline on the active tab) plus a top bar with the Forja logo and category labels (Films, TV Shows, Anime — visual only for now). On phone and tablet, a bottom navigation bar. You can hide, show, and reorder additional tabs in Settings.

## How to open it

The tab bar is always visible after the app finishes loading. **Settings** is always pinned at the bottom of the desktop rail and cannot be hidden from the navbar list.

## What you can do

- Tap any tab to switch sections instantly (tabs stay mounted in memory for fast switching)
- On desktop, the left rail is a **fixed-width** column (grey icons, Netflix-style underline on the active tab); the body is inset so content is not hidden under icons
- The **top bar** (logo + Films / TV Shows / Anime) appears on **Home only**; other tabs use their own headers
- Open **Settings → Navigation Bar** to toggle tabs on/off and drag to reorder
- Jump to Search or other tabs from deep links inside the app (e.g. from a Stremio addon result)

## Desktop shell layout

- **Top bar (Home only):** large logo + Films / TV Shows / Anime (Films underlined by default)
- **Left rail:** fixed width; profile placeholder (top), your configured tabs (center), Settings (bottom); muted grey icons
- **Body:** flat `bgDark` — no ambient glow blobs or edge vignettes; Home hero uses text-only Watch Now plus bare info and add-to-list icons

## Available tabs

Home · Discover · Similar · Media Downloader · Search · My List · Magnet · Live Matches · IPTV · Audiobooks · Books · Music · Comics · Manga · Jellyfin · Anime · Anime Arabic · Asian Drama · Arabic · Settings

## Tips

- Hide tabs you never use to reduce clutter — they can be re-enabled anytime
- Movie and series details open on top of the current tab; the player opens full-screen from there

## Related

- [Navigation bar settings](../settings/navigation-bar.md)
- [Home](../movies-tv/home.md)
