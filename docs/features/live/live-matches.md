# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from **Forja Live** engine catalogs (Streamed, PPV, StreamFree by default; TimStreams, ESPN, … optional), installed **Stremio** sport addons, and **Forja Sports** — the same enabled **Catalog** JS schedule as Forja Live, matched to channels on your own Xtream portal. Browse by sport category, pick a match, and watch in the native IPTV player. Some third-party streams cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Sports** in the navigation bar. The tab is a catalog hub (`plugins/hubs/live_sports`) — pack layout is generic `kit.list` with `source: live_schedule` (no CatalogShell top menu like Home). Host chrome keeps **Catalog**, **Schedule**, **Refresh**, and **Portals** when Forja Sports is enabled. **Providers** / **Live TV** are on match detail.

## What you can do

- Use **Catalog** to pick a schedule source and **Schedule** for status/horizon (**Airing** / **Upcoming** / windows). Opening a match lists every enabled provider in **Providers** on the detail page. **Refresh** reloads; **Portals** appears when Forja Sports is enabled.
- Switch sport category circles (centered on desktop and TV) when two or more sports are in the schedule — the row is hidden when only one category applies (e.g. football only). **24/7** covers always-on channels from catalogs that expose them (no schedule date — e.g. Willow Cricket, Tennis Channel, Rally TV). Those appear only on the 24/7 chip — hidden from All and from other sports — and stay tappable as LIVE
- Live Matches uses **card view** on phone, desktop, and TV (timeline view removed). Top bar is **Catalog** + **Schedule** (+ **Portals** when Forja Sports is enabled) + **Refresh**. Opening a match pushes the **detail** page; **Providers** merges Forja Live with Stremio; **Live TV** lists Xtream-matched channels. On TV, D-pad: **Catalog → schedule → Refresh → Portals (when shown) → sport chips → match cards**. **↑** from chips returns to the top bar. Empty lists offer **Refresh**. Entering the tab restores the last grid focus
- Browse upcoming and live events — live matches appear first. Only **live** matches are tappable and show the play button (green and floated upward, with a slowly pulsing play icon, on hover/focus). Upcoming cards show the start time badge only. Cards show start–finish (or kickoff only) above the match title when schedule data is available. Catalogs that report concurrent viewers (PPV, StreamFree, TimStreams, WatchFooty, …) show a viewer count on the card; when the same event is merged across catalogs, the counts are **added**. Merging treats PPV-style **Away at Home** and Streamed-style **Home vs Away** as the same fixture (team order / connector do not matter). Opening a live card always opens the stream picker — if nothing resolved, the panel says **No streams available** (cards do not show a separate “Not yet available” badge). The stream picker header totals viewers across every listed stream (per-stream when the source provides it, otherwise each catalog’s audience once); rows show the same. Cards refresh ● LIVE badges about once a minute while the tab is open.
- Open a **live** match to open its **detail** page — full-screen cinematic hero. Under the title, **Providers** and **Live TV** toggle which list shows on the hero:

  - **Providers** — Forja Live streams (PPV, Streamed, TimStreams, … from every enabled catalog provider) **plus** matching **Stremio** addon streams in one list. Rows load as each catalog unlocks (progressive); the source list stays cached ~30 minutes for the same fixture (reopen skips resolve); **Refresh** on the schedule or retry on the detail page busts that cache.
  - **Live TV** — channels on your Xtream portal matched for this fixture (**Forja Sports** IPTV resolve). Same ~30-minute fixture cache as Providers (stable event key — not catalog row id); **Refresh** / retry busts it. Specific TV guide names (e.g. Sky Sports Main Event, beIN 1) match immediately; bare brands from LiveOnSat / Live Soccer TV (e.g. just **DAZN**) only appear when the channel’s EPG names this fixture — not every numbered DAZN/Paramount clone. On wide layouts, a **Categories** rail (portal groups + **All**) sits beside the channel list — same idea as the IPTV Live browser. A **search** icon appears next to the Live TV tab (same expand-to-field animation as IPTV); type to filter channels by name / group.

  Rows load in parallel; tap a card to play in the native IPTV player. **Forja Live** resolves through the live sport plugin while Providers loads; on miss shows an error toast — never the site embed player. WatchFooty `wfty.st` HLS uses the sportsembed **player page** as Referer (same as the website) via the local HLS proxy — a root `sportsembed.su/` Referer is rejected by the CDN. Back returns to the match grid.
- Back / Escape exits the player and **stops audio**. On **Android TV**, remote **Back** twice leaves; remote **Exit** is separate
- On **Android TV**, pressing **Home** (or switching to another app) **pauses** the live stream; returning to Forja resumes. Desktop can keep playing in the background.
- When a **Forja Live** match has several streams, the detail page lists them as cards — inline rows (e.g. PPV) appear at once; each catalog mirror resolves in parallel and **rows land as they arrive** (status shows **N found · still searching…** while more load). Dead listings are dropped. Tap a card to play in the native IPTV player; if a row still needs unlock on pick, progress advances through **Unlocking source…**, **Preparing playback…**, and **Loading other servers…** when needed. On miss, a toast appears. Stream cards use the same flat movie **Sources** tile (fill + soft border on hover/focus, **HD** chip before the title, viewer count and provider on the right) — same for **Stremio** and **Forja Sports**. Hover/focus paints a left status strip: **green** if a probeable play URL is alive, or if the row is signed Streamed/WatchFooty HLS (those CDNs need Referer — a bare HTTP check would look dead while the player still works); **red** only when a probeable URL fails. **Forja Live**, **Stremio**, and **Forja Sports** multi-source sessions in the native player share the same **Source** menu: the row that is playing shows **Playing**, scrolls into view when you open the menu, and on TV takes D-pad focus first (**↑/↓** / **OK** to switch)
- Double-click the video to enter/exit fullscreen on desktop. On **TV**, there is no fullscreen button — the player is already immersive
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- Escape still backs out of the player on all platforms (and stops the stream)
- The **Stremio** Live assignment uses sport catalogs on disk — opening Live Sports does not re-fetch every installed VOD addon first. Opening **Stremio** itself refreshes only Live-assigned addons.

## Related

- [IPTV — Xtream](iptv-xtream.md) — portals reused by **Forja Sports** matching
- [Forja Sports](../settings/forja-sports.md) — setup for Live Matches → Forja Sports (stream resolve + live plugin toggles)
- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
