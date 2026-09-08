# Live Sports

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **hub pack** (ForjaHQ Live Sports / Live Sports Cards) — same class as Anime or Asian Drama. The tab mounts **KitShell** from pack `nav` + `layout`, composing generic kit primitives:

- **Top bar** — Catalog / Schedule filter badges + Refresh, plus top-right **Portals** (same IPTV panel; used by Live TV / Forja Sports matching)
- **Category bar** — sport mood circles with icons (dynamic from the schedule)
- **List** — dense match rows (list pack) or landscape cards (Cards pack)
- **Streams** — Providers / Live TV (right panel on list pack; hero details on Cards)

Host only registers opaque schedule/stream adapters (`live_schedule`) via generic kit boot (`KitLiveBoot`) — MetaRuntime `feed` on the hub pack, resolve panel, and IPTV portal match under `features/iptv/portal_sports/` (RFC-092). **Portals** top-bar chip and side panel are foundation design (`KitPortalsChip` / `KitSidePanelOverlay` / `KitPortalListPanel`); IPTV wires data via `IptvPortalsChromeHooks` and play/resolve via `IptvKitHooksRegister` (RFC-095). Hub packs own layout + schedule composition (`ctx.host.liveFeed.load`). There is **no** root-app Live Sports product tree and **no** built-in Addons → Live Sports host row (RFC-093). When the hub pack is installed, its `settings` show under **Settings → Addons** (pack-discovered) and on the Forja Packs expand.

Schedules come from enabled Forja Live **catalog** plugins (Streamed, PPV, StreamFree by default; TimStreams, ESPN, MobiKora, … optional). Streams come from **live** resolve packs, installed **Stremio** sport addons, and **Live TV** (your Xtream/Stalker/M3U portals matched to the fixture). Install and enable the hub pack under **Settings → Forja Packs** — that is the product on/off.

## How to open it

1. Install and enable a Live Sports hub pack under **Settings → Forja Packs** (ForjaHQ Live Sports and/or Live Sports Cards).
2. Configure **Setup** (Forja Live / Sports, merge, leagues) under **Settings → Addons → Live Sports** (appears when the hub is installed) or by expanding the hub under Forja Packs.
3. Show the tab under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Browse a **list of matches** (time, teams, status) on the list pack — loading uses the same dense-row layout (not cards). Tap a match to open the **right panel** (~40% width on desktop/TV) with **Providers** and **Live TV**. On phone the panel is a near-full-width sheet.
- Use **Catalog** / **Schedule** in the top bar. **Schedule** opens Status (Airing / Upcoming / Airing + upcoming) and Horizon (1h–24h) — same sheet as before. Returning to the tab or a filter you already loaded reuses the recent schedule cache; **Refresh** (and pull-to-refresh) forces a full reload.
- Pick an **Xtream** or **Stalker** portal from top-right **Portals** (same panel as IPTV; needed for **Live TV** matching when Forja Sports is on).
- Filter by **sport circles** in the category bar when more than one sport is in the list. **24/7** covers always-on channels.
- On the **Live Sports Cards** tab, browse a **landscape match card** grid and open **hero details** (Providers / Live TV in a two-column stream grid on desktop; shell navbar stays visible). Same streams as the side panel.
- Tap a stream row to play in Forja’s **native** live player (never an embed WebView for Forja Live). If unlock fails, you get **No playable stream**.
- Pull-to-refresh / shell refresh force-reloads the match list (same as **Refresh**). With **Merge matching events** on (hub **Setup** under Forja Packs), matching events across catalogs may collapse into one row.

## Tips

- Streams are third-party — availability changes with broadcasts and region.
- **Providers** soft-matches the same fixture across enabled Forja Live catalogs and installed Stremio sport addons, so one tap can list mirrors from Streamed, PPV, StreamFree, and others when they carry that event.
- Escape / Back closes the streams panel (or details page), then leaves the player and stops audio.
- **Merge matching events** is **off** by default — leave it off for large schedules. With merge off, cards stay separate; Providers still pulls sibling catalog streams for the tapped game.
- Enable or disable individual schedule catalogs under **Settings → Forja Packs** (expand a live pack).

## Related

- [IPTV](../iptv/iptv.md) — portals used by Live TV matching
- [Platforms](../getting-started/platforms.md)
- [Forja Sports](../settings/forja-sports.md)
