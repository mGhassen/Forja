# IPTV — Xtream

> Connect Xtream Codes portals — live TV, VOD, series, and EPG.

## What it is

The IPTV tab supports **Xtream Codes** portals. The tab opens on the **catalog** (categories + channels). Pick a portal from the side panel, switch **Live / Movies / Series** from the top bar, and play in the IPTV player.

## How to open it

Tap **IPTV** in the navigation bar. If you used a portal before, its catalog loads automatically; otherwise choose a portal from the **Portals** panel.

## What you can do

- Open the **Portals** panel (top bar) to add, scrape, search, favorite, or select providers
- Switch **Live**, **Movies**, and **Series** from section chips in the top bar
- Catalog is **cached in-session** per portal/section — switching chips reuses the last fetch
- Hover (or focus) a section chip to reveal **Reload** and force a fresh catalog fetch
- Browse live channels by category
- **Search** live, movie, and series catalogs (search icon → bar slides in; filters groups and channels as you type; close clears search)
- Watch VOD movies and series with seasons/episodes
- View EPG (program guide) when the portal provides it — disable in **Settings → Playback → IPTV programme guide (EPG)** to skip loading guide data
- Favorite portals in the Portals panel (star icon)
- Portal row actions (**copy / edit / delete**): hover the right ~10% of the row, or keep hovering 3s — also on TV focus
- Play in the IPTV player screen
- Change live channels from the in-player channel guide (groups + channel list overlay)
- Search channels from the in-player search overlay (matches name or category) — dismiss with the borderless **Close** control in the header
- View programme guide (NOW / NEXT with progress) as a floating card at the bottom-right of the player when your portal provides EPG
- Switch audio tracks and subtitles from the player controls when the stream provides them

## Setup

1. Get portal URL, username, and password from your IPTV provider
2. Open **Portals** → **Add** (or **Scrape** to discover providers)
3. Tap a portal in the list to load its catalog

## Tips

- **Portals** panel on the right (desktop / Android TV) holds scrape, add, and the full portal list — search filters by name or URL
- Section chips (**Live** / **Movies** / **Series**) switch the catalog; data stays cached until you hit the hover **Reload** control
- On **Android TV**, search fields focus in browse mode first — press **Enter** on the remote to open the keyboard, then type
- Press **Back** / **Escape** to close the Portals panel before leaving the tab
- While watching **live TV**, tap the grid icon in the player controls to open the channel guide
- Programme guide is optional — turn off **IPTV programme guide (EPG)** under Settings → Playback if you want zero EPG network requests
- Portal quality varies — timeouts usually mean provider or network issues
- Series VOD uses the same player as live with seek support when the stream allows

## Related

- [IPTV — M3U](iptv-m3u.md)
- [Player](../playback/player.md)
