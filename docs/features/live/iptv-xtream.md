# IPTV — Xtream

> Connect Xtream Codes, M3U playlists, and Stalker portals — live TV, movies, and series.

## What it is

The **IPTV** tab comes from the **IPTV hub pack** (install under **Settings → Forja Packs**). Same mount model as other hubs: pack declares the page; the app validates and paints it. Supports **Xtream Codes**, **M3U/M3U8**, and **Stalker / Ministra**. Play uses the host live player.

## How to open it

1. Install and enable the **IPTV** hub pack under **Settings → Forja Packs**, then show **IPTV** under **Settings → Features** / the nav rail.
2. Tap **IPTV**. Open **Portals** to add or switch a provider, or use **Settings → Addons → IPTV** for portal fields.

## What you can do

- Switch **Live**, **Movies**, and **Series** from the pack top bar — the shelf shows the selected section; hover (or TV focus) expands the other options and temporarily hides **Portals**. While a shelf loads, the grid shows a centered spinner with **Loading channels/movies/series** (not placeholder cards). The app keeps the portal catalog on device and only paints one page of titles at a time (scroll for more). Channels appear as soon as the first page returns; **NOW / NEXT** EPG fills on each card afterward (not before the grid).
- Browse the **category list** on the left and **channel cards** on the right (logo + title under the mark, **NOW / NEXT** EPG strip when short EPG is available; long-press a card for the programme list). An always-open **Search** field sits above the categories — filter channels or category names without leaving the rail (**Cmd/Ctrl+F** focuses it). Hover probes stream health (green/red border). Type a letter while the pointer is over the rail or channel grid to jump to matching names. On **Live**, the rail includes **Favorites** and **Already watched**; hover a category to **pin** it, or hold-drag to reorder (playlist order). Star a channel on its card to add it to Favorites; recently played channels land under Already watched (last 30 on this device). Reopening Live restores your last category and scrolls to the last-played channel (highlight only — no autoplay). Leaving the player lands on the channel you were watching. On TV, in Favorites / Already watched, hold **OK** ~1s to jump to that channel’s portal group without playing. Narrow windows use Sources-style rows — bordered tile, green left bar when selected, health on the bar — not fat rounded cards; on leanback TV, channel logos load after a short idle so skimming categories does not thrash images. Switching categories (or Favorites / Already watched) and **Search** filter the already-loaded catalog instantly — they do not re-fetch channels. **Movies** / **Series** keep poster cards.
- Open **Portals** from the top bar — add, import a share code, select, favorite, share, edit, or remove portals (forms and inventory from the pack). On a wide desktop, hover a portal row for ~1s to see status, seats, ports, and timezone (narrow windows skip the peek). The chip shows your active portal from local vault; the full portal list loads only when you open the panel.
- Open movies/series in shared **hub details** — series episodes come from pack `details` (`meta.videos`); optional TMDB enrich when enabled
- Play live channels and VOD in the live player (player opens immediately; in-player channel guide / search / EPG attach when ready). Progressive live (Xtream `.ts`) opens the CDN URL in MediaKit with ffmpeg reconnect — no local relay.
- Optional **Forja Sports** matching for Live TV when the toggle is on in Addons → IPTV

## Setup

1. Get portal URL, username, and password from your IPTV provider
2. **Portals → Add** or **Import** (share code), or fill **Settings → Addons → IPTV** (platform / URL / credentials)
3. Select the portal and open **Live**, **Movies**, or **Series**

## Tips

- See [IPTV — M3U](iptv-m3u.md) and [IPTV — Stalker](iptv-stalker.md) for type-specific setup
- Portal passwords use the device vault; share codes and CSV export still contain secrets — keep them private
- Clear stale catalog cache from **Settings → Data & backup → IPTV portal cache** when the pack is installed
- Operators manage the shared portal pool via [Catalog ops](iptv-catalog-ops.md)

## Related

- [IPTV — M3U](iptv-m3u.md)
- [IPTV — Stalker](iptv-stalker.md)
- [Live Sports](live-sports.md)
- [Hub details](../hubs/hub-details.md)
