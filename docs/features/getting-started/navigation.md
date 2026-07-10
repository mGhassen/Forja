# Navigation

> Move between movies, live TV, music, reading, and more from the main tab bar.

## What it is

Forja uses a tab-based shell. **Default tabs:** Home, Search, Asian Drama, Anime, IPTV, Live Matches, My List, and Settings. On desktop you get a fixed-width left rail (logo + grey icons, Netflix-style underline on the active tab). On phone and tablet, a flat bottom navigation bar. You can hide, show, and reorder additional tabs in Settings.

## How to open it

The tab bar is always visible after the app finishes loading. **Settings** is always pinned at the bottom of the desktop rail and cannot be hidden from the navbar list.

## What you can do

- Tap any tab to switch sections instantly (tabs stay mounted in memory for fast switching)
- On desktop, the left rail is a **fixed-width** column; the body is inset so content is not hidden under icons
- On **Home (desktop)**, a Films / TV Shows / Categories menu overlays the hero and slides away as you scroll
- **Search (desktop)** uses a full-page layout with a left search column — no separate shell search bar
- Open **Settings → Navigation Bar** to toggle tabs on/off and drag to reorder
- Jump to Search or other tabs from deep links inside the app (e.g. from a Stremio addon result)

## Desktop shell layout

- **Home menu (desktop):** Films / TV Shows / Categories overlaid on the hero; Categories opens a mood picker
- **Left rail:** Forja logo (top), your configured tabs (center), Settings (bottom); muted grey icons with hover feedback
- **Body:** flat `bgDark`; Home hero is full-bleed with pill **Play** plus a combined **info | add** pill for details and My List

## Android TV

- Same left **nav rail** as desktop (no bottom bar); D-pad moves focus with a white ring on the active control
- UI renders at **80% density** (`tvUiScaleFactor`) — layout uses a larger virtual viewport then scales to fit, so cards, text, and spacing match desktop proportions on 1080p panels
- **Nav rail:** UP/DOWN only move between nav items (trap at Home and Settings); LEFT is trapped; **RIGHT** returns to the **active** tab’s last focus (row, hero, or default) without switching tabs; **Enter/Select** switches to the focused nav tab and restores that tab’s focus
- **Catalog rows:** LEFT/RIGHT move within the row only (no vertical scroll jump); DOWN/UP move between rows and restore each row’s own last-focused item (not the column from the row you left); last row DOWN stops (no escape to nav)
- **Hero:** UP from the first row scrolls the hero fully visible and focuses Play; LEFT from Play focuses the **active** nav tab (not a geometric neighbor)
- **Home, Search, Anime, Asian Drama, My List, Settings, IPTV, and Live Matches** use the **same card sizes, spacing, and section layout as desktop**; D-pad focus and coordinator-registered rows/chips are unchanged
- Search uses the **two-column desktop layout** on TV (trending suggestions, focused-result detail pane, fluid results grid); D-pad lands on suggestions first — not the search field
- Phone layout is unchanged — TV behavior applies only on Android TV / leanback devices
- **Dev:** `flutter run --dart-define=FORJA_ANDROID_TV=true` forces TV profile on any Android device (layout/defaults only — not leanback launcher proof). See [Platforms](platforms.md#android-tv-development).

## Available tabs

Home · Discover · Similar · Media Downloader · Search · My List · Magnet · Live Matches · IPTV · Audiobooks · Books · Music · Comics · Manga · Jellyfin · Anime · Anime Arabic · Asian Drama · Arabic · Settings

## Tips

- Hide tabs you never use to reduce clutter — they can be re-enabled anytime
- Movie and series details open on top of the current tab; the player opens full-screen from there

## Related

- [Navigation bar settings](../settings/navigation-bar.md)
- [Home](../movies-tv/home.md)
