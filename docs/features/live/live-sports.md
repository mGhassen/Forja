# Live Sports

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **hub pack** (ForjaHQ Live Sports / Live Sports Cards) — same class as Anime or Asian Drama. The tab mounts **KitShell** from pack `nav` + `layout`, composing generic kit primitives:

- **Top bar** — Catalog / Schedule filter badges + Refresh, plus top-right **Search** (filter loaded events) and **Portals** (same IPTV panel; used by Live TV / Forja Sports matching)
- **Category bar** — sport mood circles with icons (dynamic from the schedule)
- **List** — dense match rows (list pack) or landscape cards (Cards pack)
- **Streams** — Providers / Live TV (right panel on list pack; hero details on Cards)

Host only registers opaque schedule/stream adapters (`live_schedule`) via generic kit boot (`KitLiveBoot`) — MetaRuntime `feed` on the hub pack, resolve panel, and IPTV channel search under `features/iptv/channel_search/` (RFC-096). **Portals** top-bar chip and side panel are foundation design (`KitPortalsChip` / `KitSidePanelOverlay` / `KitPortalListPanel`); IPTV wires data via `IptvPortalsChromeHooks` and play/resolve via `IptvKitHooksRegister` (RFC-095). Hub packs own layout + schedule composition (`ctx.host.liveFeed.load`) and put `sportMatchGame` on feed rows for Live TV. There is **no** root-app Live Sports product tree and **no** built-in Addons → Live Sports host row (RFC-093). When the hub pack is installed, its `settings` show under **Settings → Addons** (pack-discovered) and on the Forja Packs expand.

Schedules come from enabled Forja Live **catalog** plugins (Streamed, PPV, StreamFree by default; TimStreams, ESPN, MobiKora, … optional). Catalogs are **schedule only** — they do not find or unlock streams. Streams come from **live** resolve packs, installed **Stremio** sport addons, and **Live TV** (your Xtream/Stalker/M3U portals matched to the fixture). Install and enable the hub pack under **Settings → Forja Packs** — that is the product on/off.

## How to open it

1. Install and enable a Live Sports hub pack under **Settings → Forja Packs** (ForjaHQ Live Sports and/or Live Sports Cards).
2. Configure **Setup** (Forja Live / Sports, merge) under **Settings → Addons → Live Sports** (appears when the hub is installed) or by expanding the hub under Forja Packs.
3. Show the tab under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Browse a **list of matches** (time, teams, status) on the list pack — while catalogs load you see **Loading live catalogs…** (and top-bar progress in place of **Refresh**); rows appear as each catalog finishes, not only after every site is done. A thin scrollbar stays visible on the match list (and Cards grid) so you can see how far you are in a long schedule. Tap a match to open the **right panel** (~40% width on desktop/TV) with **Providers** and **Live TV**. On phone the panel is a near-full-width sheet. On **Android TV**, OK on a match (or → when that match is already selected) moves D-pad focus to **Providers**; ← from Providers / stream rows returns to the match list. The selected tab uses green label text; hover / D-pad focus uses a light green tint (not a solid fill). Leaving a match player and returning keeps the loaded schedule (no full catalog re-scrape); use **Refresh** to force a reload.
- Use **Catalog** / **Schedule** in the top bar. **Catalog** lists Forja Live packs plus each Stremio addon enabled for **Live** (Settings → Sources). The chip shows **All** or the selected catalog name (same style as Schedule). Pick an addon name to browse that sport schedule. **Schedule** opens Status (Airing / Upcoming / Airing + upcoming) and Horizon (1h–24h) — default is **Airing** (in-play and 24/7 only). Changing Schedule refilters the already-loaded rows (no catalog re-scrape); **Refresh** (and pull-to-refresh) forces a full reload. Returning to the tab reuses the recent schedule cache.
- Pick an **Xtream** or **Stalker** portal from top-right **Portals** (same panel as IPTV; needed for **Live TV** matching when Forja Sports is on). Opening the Live Sports hub probes the active portal so the Portals chip status dot updates (spinner → green/red) without waiting for hover/focus. On **Android TV**, OK on **Portals** (or → / ↓ while the panel is open) moves D-pad to the **selected** portal in the list — same as the IPTV hub. The Portals panel covers the sport category bar and match list (under the top bar).
- Use top-right **Search** (left of **Portals**) to filter the loaded schedule by team, match title, or sport — no re-scrape. Sport circles stay based on the full schedule. Clear with the field’s **X** or Escape. **Cmd/Ctrl+F** opens search. On narrow layouts, Search opens a small dialog instead of the expanding field. On **Android TV**, D-pad walks **Catalog** / **Schedule** / **Refresh** / **Search** / **Portals**; OK on Search opens the field (browse until OK again for the keyboard).
- Filter by **sport circles** in the category bar when more than one sport is in the list. **24/7** covers always-on channels. The bar stays visible while the schedule loads or refreshes (All until sports appear). On **Android TV**, OK from the nav rail lands D-pad on the sport circles (All); **↑** reaches **Catalog** / **Schedule** / **Refresh**; **←** / **→** walk those chips, **Search**, and **Portals**.
- On the **Live Sports Cards** tab, browse a **landscape match card** grid and open **hero details** (Providers / Live TV in a two-column stream grid on desktop; shell navbar stays visible). Same streams as the side panel.
- Tap a stream row to play in Forja’s **native** live player (never an embed WebView for Forja Live). If unlock fails, you get **No playable stream**. Stream unlock glue (GOAT / GASM) updates with the Live Sports **live pack** — **Reload** / **Update** that pack under Forja Packs when streams stop unlocking after an upstream change.
- In the player, use the bottom **swap** control to open **Source** (same floating menu chrome as Quality / Player). Rows use the same card layout as Cards **Providers** (title, provider, HD badge, viewer count, host footer). The playing row stays highlighted; hover or D-pad focus on another row runs the same left-bar health check as the pre-play Providers panel.
- Pull-to-refresh / shell refresh force-reloads the match list (same as **Refresh**). With **Merge matching events** on (hub **Setup** under Forja Packs), matching events across catalogs may collapse into one row.

## Tips

- Streams are third-party — availability changes with broadcasts and region. The **schedule** can list a live match before any site has links. **Providers** only shows a row when that site actually has stream links; if the site says zero links, Forja shows no provider for it (no fake preparing row).
- **Providers** soft-matches the same fixture across enabled Forja Live **stream** catalogs (ones that link to a resolve pack) and installed Stremio sport addons — Streamed, PPV, StreamFree, and similar. TV-guide catalogs (broadcast channel lists) feed Live TV name matching only; they are not stream sources. Stream unlock runs in the live resolve pack when you play a real listed mirror.
- Escape / Back closes the streams panel (or details page), then leaves the player and stops audio.
- **Merge matching events** is **off** by default — leave it off for large schedules. With merge off, cards stay separate; Providers still pulls sibling catalog streams for the tapped game.
- Enable or disable individual schedule catalogs under **Settings → Forja Packs** (expand a live pack).

## Related

- [IPTV](../iptv/iptv.md) — portals used by Live TV matching
- [Platforms](../getting-started/platforms.md)
- [Forja Sports](../settings/forja-sports.md)
