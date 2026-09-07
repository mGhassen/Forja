# Live Sports

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **hub pack** (ForjaHQ Live Sports / Live Sports Cards) — same class as Anime or Asian Drama. The tab mounts **KitShell** from pack `nav` + `layout`, composing generic kit primitives:

- **Top bar** — Catalog / Schedule filter badges + Refresh
- **Category bar** — sport mood circles with icons (dynamic from the schedule)
- **List** — dense match rows (list pack) or landscape cards (Cards pack)
- **Streams** — Providers / Live TV (right panel on list pack; hero details on Cards)

Host only registers opaque schedule/stream adapters (`live_schedule`) via generic kit boot (`KitLiveBoot`) — MetaRuntime `feed` on the hub pack, resolve panel, and IPTV portal match under `features/iptv/portal_sports/` (RFC-092). Hub packs own layout + schedule composition (`ctx.host.liveFeed.load`). There is **no** root-app Live Sports product tree and **no** host Live Sports feature tab without a hub pack.

Schedules come from enabled Forja Live **catalog** plugins (Streamed, PPV, StreamFree by default; TimStreams, ESPN, MobiKora, … optional). Streams come from **live** resolve packs, installed **Stremio** sport addons, and **Live TV** (your Xtream/Stalker/M3U portals matched to the fixture). **Settings → Addons → Live Sports** turns catalog/settings capability on or off — it does not invent a navbar tab by itself.

## How to open it

1. Install and enable a Live Sports hub pack (ForjaHQ Live Sports and/or Live Sports Cards).
2. Turn on **Settings → Addons → Live Sports** so catalogs and Live Sports settings are available.
3. Show the tab under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Browse a **list of matches** (time, teams, status) on the list pack — loading uses the same dense-row layout (not cards). Tap a match to open the **right panel** (~40% width on desktop/TV) with **Providers** and **Live TV**. On phone the panel is a near-full-width sheet.
- Use **Catalog** / **Schedule** in the top bar. **Schedule** opens Status (Airing / Upcoming / Airing + upcoming) and Horizon (1h–24h) — same sheet as before. **Refresh** reloads the schedule.
- Filter by **sport circles** in the category bar when more than one sport is in the list. **24/7** covers always-on channels.
- On the **Live Sports Cards** tab, browse a **landscape match card** grid and open **hero details** (Providers / Live TV in a two-column stream grid on desktop; shell navbar stays visible). Same streams as the side panel.
- Tap a stream row to play in Forja’s **native** live player (never an embed WebView for Forja Live). If unlock fails, you get **No playable stream**.
- Pull-to-refresh / shell refresh reloads the match list. With **Merge matching events** on (hub Setup under Settings → Addons → Live Sports), matching events across catalogs may collapse into one row.

## Tips

- Streams are third-party — availability changes with broadcasts and region.
- Escape / Back closes the streams panel (or details page), then leaves the player and stops audio.
- **Merge matching events** is **off** by default — leave it off for large schedules.
- Enable or disable individual schedule catalogs under **Settings → Addons → Live Sports**.

## Related

- [IPTV](../iptv/iptv.md) — portals used by Live TV matching
- [Platforms](../getting-started/platforms.md)
