# Live Sports

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **hub pack** (ForjaHQ Live Sports) — same class as Anime or Asian Drama. The tab mounts **KitShell** from pack `nav` + `layout`, composing generic kit primitives:

- **Top bar** — pack `kit.topBar` actions: Catalog / Schedule / Refresh (left), then **Search**, **List/Cards** icon, and **Portals** (trailing). Host only paints verbs the pack lists — it does not inject chrome.
- **Category bar** — sport mood circles with icons (dynamic from the schedule)
- **List** — dense match rows or landscape cards (toggle from the top bar; default **List**)
- **Streams** — Providers / Live TV in a **side panel** or a **detail page** (pack Setup → **Open matches in**; default side panel)

Host only registers opaque schedule/stream adapters (`live_schedule`) via generic kit boot (`KitLiveBoot`) — MetaRuntime `feed` on the hub pack, resolve panel, and IPTV channel search under `features/iptv/channel_search/` (RFC-096). The hub pack declares Search / view / Portals in `kit.topBar` (`trailing: true`). Host paints those verbs via kit primitives + `packActionBuilders['portals']` (IPTV data) — it does **not** inject trailing chrome. Portals panel shell is foundation design (`KitPortalsChip` / `KitSidePanelOverlay`); play/resolve via `IptvKitHooksRegister` (RFC-095).

Schedules and streams come from installed **live_sport** plugins (Catalog / Providers capability toggles in Settings). Schedule capability is fixtures only — it does not unlock play. Resolve capability discovers mirrors and unlocks to native play. **Live TV** still matches your Xtream/Stalker/M3U portals to the fixture. Install and enable the hub pack under **Settings → Forja Packs** — that is the product on/off.

## How to open it

1. Install and enable the Live Sports hub pack under **Settings → Forja Packs**.
2. Configure **Setup** (Forja Live / Sports, merge, open mode) under **Settings → Addons → Live Sports** (appears when the hub is installed) or by expanding the hub under Forja Packs.
3. Show the tab under **Settings → Features** / the nav rail (pack first-seen defaults the tab on).

## What you can do

- Browse matches as a **dense list** or **landscape cards** — tap **List** / **Cards** in the top bar (left of **Portals**) to switch; the choice persists. While catalogs load you see **Loading live catalogs…** (and top-bar progress in place of **Refresh**); rows appear as each catalog finishes, not only after every site is done. A thin scrollbar stays visible on the schedule so you can see how far you are. Tap a match to open streams in the **side panel** (~40% width on desktop/TV) or a **detail page** — set under hub **Setup → Open matches in**. On phone the panel is a near-full-width sheet. **Providers** lists mirrors as each stream pack finds the fixture (progressive) — a small spinner sits at the far right of the Providers / Live TV tab row (next to channel search when that tab is open) until every pack finishes. On **Android TV**, OK on a match (or → when that match is already selected) moves D-pad focus to **Providers**; ← from Providers / stream rows returns to the match list. The selected tab uses green label text; hover / D-pad focus uses a light green tint (not a solid fill). On **Live TV**, a search icon next to the tab expands like IPTV search and filters portal channels by name or group; wide layouts also show a **Categories** rail (**All** + portal groups) beside the channel list. Leaving a match player and returning keeps the loaded schedule (no full catalog re-scrape); use **Refresh** to force a reload.
- Use **Catalog** / **Schedule** in the top bar. **Catalog** lists Forja Live packs plus each Stremio addon enabled for **Live** (Settings → Sources). The chip shows **All** or the selected catalog name (same style as Schedule). Pick an addon name to browse that sport schedule — after **All** has loaded, switching to one catalog (e.g. PPV) refilters the warm scrape (no re-fetch). **Schedule** opens Status (Airing / Upcoming / Airing + upcoming) and Horizon (1h–24h) — default is **Airing** (in-play and 24/7 only). Changing Schedule refilters the already-loaded rows (no catalog re-scrape); **Refresh** (and pull-to-refresh) forces a full reload. Returning to the tab reuses the recent schedule cache.
- Pick an **Xtream** or **Stalker** portal from top-right **Portals** (same panel as IPTV; needed for **Live TV** matching when Forja Sports is on). Opening the Live Sports hub probes the active portal so the Portals chip status dot updates (spinner → green/red) without waiting for hover/focus. On **Android TV**, OK on **Portals** (or → / ↓ while the panel is open) moves D-pad to the **selected** portal in the list — same as the IPTV hub. The Portals panel covers the sport category bar and match list (under the top bar).
- Use top-right **Search** (left of **List/Cards** and **Portals**) to filter the loaded schedule by team, match title, or sport — no re-scrape. Sport circles stay based on the full schedule. Clear with the field’s **X** or Escape. **Cmd/Ctrl+F** opens search. On narrow layouts, Search opens a small dialog instead of the expanding field. On **Android TV**, D-pad walks **Catalog** / **Schedule** / **Refresh** / **Search** / **List|Cards** / **Portals**; OK on Search opens the field (browse until OK again for the keyboard).
- Filter by **sport circles** in the category bar when more than one sport is in the list. **24/7** covers always-on channels. The bar stays visible while the schedule loads or refreshes (All until sports appear). On **Android TV**, OK from the nav rail lands D-pad on the sport circles (All); **↑** reaches **Catalog** / **Schedule** / **Refresh**; **←** / **→** walk those chips, **Search**, **List/Cards**, and **Portals**; **↓** from a sport circle or from **Portals** / Catalog returns to the **last focused match** (not always the first row).
- With **Cards** + **Detail page**, browse landscape match cards and open **hero details** (Providers / Live TV in a two-column stream grid on desktop — left column fills first; soft frosted scrim from the title to the bottom, full width to the screen edges; shell navbar stays visible). Same streams as the side panel — Live TV keeps the search icon next to the tab pills and the Categories rail when the panel is wide enough. On **Android TV**, D-pad **↓** from **Providers** / **Live TV** moves into the stream list; **↑** from the first stream returns to the tabs. **Cards** + **Side panel** also works — selected card chrome highlights while the panel is open.
- Tap a stream row to play in Forja’s **native** live player (never an embed WebView for Forja Live). If unlock fails on every remaining Providers row, you get **No playable stream**. When a playing mirror dies (or unlock fails mid-failover), the player hops to the next Providers / Stremio row automatically — use **Source** to pick one yourself anytime. Brief buffering reconnects reuse the current unlock when the playlist is still good; a hard open fail or flaky CDN re-unlocks. Stream unlock runs in the live resolve pack (GOAT / GASM / sportsembed modules) — **Reload** / **Update** that pack under Forja Packs when streams stop unlocking after an upstream change.
- In the player, use the bottom **swap** control to open **Source** (same floating menu chrome as Quality / Player). Rows use the same card layout as Cards **Providers** (title, provider, HD badge, viewer count, host footer). The playing row uses brand-green text, a **Playing** label, green check, and green left bar; hover or D-pad focus on another row runs the same left-bar health check as the pre-play Providers panel.
- Pull-to-refresh / shell refresh force-reloads the match list (same as **Refresh**). With **Merge matching events** on (hub **Setup**; default on), matching events across catalogs collapse into one card.

## Tips

- Streams are third-party — availability changes with broadcasts and region. The **schedule** can list a live match before any site has links. **Providers** only shows a row when that site actually has stream links; if the site says zero links, Forja shows no provider for it (no fake preparing row).
- **Providers** finds the fixture **inside each resolve-capable pack** (each site searches its own upstream) and installed Stremio sport addons — the app does not soft-match across schedule catalogs. Broadcast-only catalogs feed Live TV name matching only; they are not stream sources. When **Merge matching events** is on, those guide channel names stay on the merged card so **Live TV** can match your IPTV portal. Unlock runs in the pack when you play a listed mirror.
- Escape / Back closes the streams panel (or details page), then leaves the player and stops audio.
- **Merge matching events** is **on** by default — same game across catalogs becomes one card (viewer counts from each catalog are added together; Providers still soft-matches every sibling). Turn it off under hub **Setup** if you want every catalog row kept separate.
- Enable or disable Catalog / Providers per site under **Settings → Forja Packs** (expand the live sports pack).

## Related

- [IPTV](../iptv/iptv.md) — portals used by Live TV matching
- [Platforms](../getting-started/platforms.md)
- [Forja Sports](../settings/forja-sports.md)
