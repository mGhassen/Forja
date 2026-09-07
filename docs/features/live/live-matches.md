# Live Sports

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **host feature** (Settings → Addons → Live Sports) — same class as IPTV. The tab mounts **KitShell** with a kit layout composed of generic primitives:

- **Top bar** — Catalog / Schedule filter badges + Refresh
- **Category bar** — sport mood circles with icons (dynamic from the schedule)
- **List** — dense match rows
- **Right panel** — Providers / Live TV streams for the selected match

Optional hub packs restyle that composition (same schedule source). **ForjaHQ Live Sports** overrides the host **Live Sports** tab (list + panel). **ForjaHQ Live Sports Cards** adds a separate **Live Sports Cards** tab (landscape cards + hero details). Both can be installed together.

Schedules come from enabled Forja Live **catalog** plugins (Streamed, PPV, StreamFree by default; TimStreams, ESPN, MobiKora, … optional). Streams come from **live** resolve packs, installed **Stremio** sport addons, and **Live TV** (your Xtream/Stalker/M3U portals matched to the fixture).

## How to open it

1. Turn on **Settings → Addons → Live Sports** (shows the tab in the nav bar).
2. Tap **Live Sports** in the rail / bottom nav.

You do **not** need a Live Sports hub pack for the **Live Sports** tab to appear (Addons only). Install **ForjaHQ Live Sports** to restyle that tab, or **ForjaHQ Live Sports Cards** for a second cards tab under **Settings → Features**.

## What you can do

- Browse a **list of matches** (time, teams, status) on the default / list pack. Tap a match to open the **right panel** (~40% width on desktop/TV) with **Providers** and **Live TV**. On phone the panel is a near-full-width sheet.
- Use **Catalog** / **Schedule** badges in the top bar to narrow sources and time window (named catalog chips come from the Live Sports hub pack; host default is **All** + horizon). **Refresh** reloads the schedule.
- Filter by **sport circles** in the category bar when more than one sport is in the list. **24/7** covers always-on channels.
- On the **Live Sports Cards** tab (Cards pack), browse a **landscape match card** grid and open a **full-bleed details** page (hero + Providers / Live TV) — same streams as the side panel, not a plain scaffold.
- Tap a stream row to play in Forja’s **native** live player (never an embed WebView for Forja Live). If unlock fails, you get **No playable stream**.
- Pull-to-refresh / shell refresh reloads the match list. With **Settings → Addons → Live Sports → Merge matching events** on, matching events across catalogs may collapse into one row.

## Tips

- Streams are third-party — availability changes with broadcasts and region.
- Escape / Back closes the streams panel (or details page), then leaves the player and stops audio.
- **Merge matching events** is **off** by default — leave it off for large schedules.
- Enable or disable individual schedule catalogs under **Settings → Addons → Live Sports**.

## Related

- [IPTV — Xtream](iptv-xtream.md) — portals reused by **Live TV** matching
- [Forja Sports](../settings/forja-sports.md) — setup for Live Sports → Forja Sports
- [Navigation](../getting-started/navigation.md) · [Features](../settings/navigation-bar.md)
