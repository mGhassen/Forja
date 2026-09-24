# Stremio catalog hub

> Browse catalogs from your installed Stremio addons — empty until you add them.

## What it is

The **Stremio** tab is a catalog hub from the ForjaHQ **Stremio** pack. It ships with **no preset rows**. When you install Stremio addons under **Settings → Addons → Stremio** and leave **Sources** (`vod`) on, each catalog those addons declare becomes a rail on this tab — same idea as Stremio’s Board.

Opening a title uses that addon’s metadata (`/meta`) and the usual **Sources** panel (Stremio streams, torrents, and other play sources you have enabled). This tab does **not** use the Home TMDB catalog.

Toggle the tab under **Settings → Features** after the pack is installed.

## How to open it

1. Install a VOD catalog addon (for example Cinemeta) in **Settings → Addons → Stremio**.
2. Install the **Stremio** hub pack under **Settings → Forja Packs** (local path or catalog URL).
3. Tap **Stremio** in the navigation bar.

## What you can do

- See one rail per catalog from your installed VOD-targeted addons (title is usually `Addon · Catalog`). The **hero** uses the first catalog’s posters (same feed as that rail — not a separate hardcoded list).
- Filter the page with top-menu **Movies** / **Series** / **Anime** chips when your installed catalogs include those types (All shows everything).
- Scroll posters and open a title for Stremio details and Sources. **Sources** opens on the **Stremio** tab; Forja providers match the title’s type (movie, TV, or anime) — not live or IPTV.
- **Search** from the hub — searches across addons that support catalog search.
- With no VOD catalog addons (or all `vod` off) the page stays empty — install or enable an addon to fill it.

## Tips

- Live / sports Stremio addons stay on **Live Sports** Catalog chips; this hub only lists **Sources** (`vod`) catalogs.
- Disable an addon or turn off its Sources chip to remove its rails without uninstalling the hub.

## Related

- [Stremio addons](../sources/stremio-addons.md)
- [Hub details](hub-details.md)
- [Home](../movies-tv/home.md) — TMDB catalog (separate from this tab)
