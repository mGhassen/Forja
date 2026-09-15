# IPTV — Xtream

> Connect Xtream Codes, M3U playlists, and Stalker portals — live TV, movies, and series.

## What it is

The **IPTV** tab comes from the **IPTV hub pack** (install under **Settings → Forja Packs**). Same mount model as other hubs: pack declares the page; the app validates and paints it. Supports **Xtream Codes**, **M3U/M3U8**, and **Stalker / Ministra**. Play uses the host live player.

## How to open it

1. Install and enable the **IPTV** hub pack under **Settings → Forja Packs**, then show **IPTV** under **Settings → Features** / the nav rail.
2. Tap **IPTV**. Open **Portals** to add or switch a provider, or use **Settings → Addons → IPTV** for portal fields.

## What you can do

- Switch **Live**, **Movies**, and **Series** from the pack top bar
- Browse the **category list** on the left and **landscape channel cards** on the right (logos + **NOW** when short EPG is available). Switch **Cards** / **List** / **Timeline** from the top bar; Search and Sort apply to the grid. Timeline `programmes` come from the pack.
- Open **Portals** from the top bar — add, select, favorite, share, edit, or remove portals (inventory from the pack)
- Open movies/series in shared **hub details** — series episodes come from pack `details` (`meta.videos`); optional TMDB enrich when enabled
- Play live channels and VOD in the live player (in-player channel guide / search / EPG use shared guide chrome). Progressive live (Xtream `.ts`) opens the CDN URL in MediaKit with ffmpeg reconnect — no local relay.
- Optional **Forja Sports** matching for Live TV when the toggle is on in Addons → IPTV

## Setup

1. Get portal URL, username, and password from your IPTV provider
2. **Portals → Add**, or fill **Settings → Addons → IPTV** (platform / URL / credentials)
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
