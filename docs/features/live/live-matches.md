# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Sports is a **host feature** (Settings → Addons → Live Sports) — same class as IPTV. The tab mounts the catalog **kit** with a host-default layout: a dense **match list** and a **right streams panel** (Providers / Live TV). An optional ForjaHQ Live Sports hub pack can replace that layout via kit `layout`; browse and play stay host-owned.

Schedules and streams come from **Forja Live** engine catalogs (Streamed, PPV, StreamFree by default; TimStreams, ESPN, MobiKora, … optional), installed **Stremio** sport addons, and **Forja Sports** (catalog schedule matched to your Xtream portal).

## How to open it

1. Turn on **Settings → Addons → Live Sports** (shows the tab in the nav bar).
2. Tap **Live Sports** in the rail / bottom nav.

You do **not** need the Live Sports hub pack for the tab to appear. Install **Forja Packs → ForjaHQ Live Sports** only if you want a pack-driven layout skin.

## What you can do

- Browse a **list of matches** (time, teams, status) — not a card grid on the standard layout. Hover / D-pad focus use a gray ink fill; the **open** match (streams panel) stays green — tint fill, left rail, title / viewers / chevron. On **Android TV**, D-pad walks the list; **→** opens into the streams panel when a match is selected.
- Tap a **live** match to open a **right panel** (~40% width on desktop/TV) with **Providers** (Forja Live + Stremio) and **Live TV** (Xtream-matched channels). Channel cards are **one per row** (full panel width). The panel sits under the sport category bar and shrinks only the match list — categories stay full width. There is no separate details page on the standard path. On TV, D-pad moves Reload / Close → Providers / Live TV → stream cards (and Live TV categories); **←** returns to the match list.
- Use the **reload** control next to Close in the streams panel header to force a fresh Providers / Live TV search — bypasses the ~30 minute source cache. Installing or removing a Stremio addon also invalidates that cache automatically.
- Tap a stream row in the panel to play in the **native** IPTV player (never an embed WebView for Forja Live). Providers unlock to HLS before open (WatchFooty sportsembed, Streamed/PPV GOAT, …). If unlock fails, you get **No playable stream** — the player does not open an embed page or reconnect forever on HTML.
- Hover / D-pad focus any **Providers** row for a short pause — grey then green/red left strip. Ready Streamed / WatchFooty / Stremio HLS probe with Referer headers. Catalog embed / pending rows still show the strip (green = listed, not a CDN check).
- **Live TV** portal channels probe on hover the same way as IPTV Live (resolve play URL via the portal, then alive-check).
- Use **Catalog** / **Schedule** in the top bar (and **Portals** when Forja Sports is enabled). Use **Search** next to **Refresh** to filter the match list by team or title. **Portals** overlays the match list and the streams panel. While catalogs are still loading, **Refresh** is replaced by a short progress line (current catalog + count). With **Settings → Addons → Live Sports → Merge matching events** on, you may also see **Merging catalogs…**. **Refresh** returns when the schedule is ready.
- Filter by sport chips when more than one sport is in the schedule; **24/7** covers always-on channels. The chip row shows only what fits at full size and scrolls horizontally for the rest (no shrinking).
- On phone, the streams panel is a near-full-width sheet; on desktop/TV it takes **40%** of the width and pushes the match list (not the category chips).

## Tips

- Streams are third-party — availability changes with broadcasts and region. Streamic may list fewer mirrors than the website: Forja only keeps ones it can unlock to native HLS (e.g. DLHD/DaddyLive), and skips iframe-only dead ends. MobiKora only lists fixtures that already have a channel link on the site.
- Escape / Back closes the streams panel, then leaves the player and stops audio
- Pack layout with `style: grid` can restore a card browse if a hub pack declares it
- **Merge matching events** (Settings → Addons → Live Sports) is **off** by default — leave it off for large schedules; turn it on only if you want the same game collapsed across catalogs

## Related

- [IPTV — Xtream](iptv-xtream.md) — portals reused by **Forja Sports** matching
- [Forja Sports](../settings/forja-sports.md) — setup for Live Sports → Forja Sports
- [Navigation](../getting-started/navigation.md) · [Features](../settings/navigation-bar.md)
