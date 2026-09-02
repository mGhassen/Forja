# Live Matches

> Watch live sports and events from aggregated stream sources.

## What it is

Live Matches pulls schedules and streams from **Forja Live** engine catalogs (Streamed, PPV, StreamFree by default; TimStreams, ESPN, … optional), installed **Stremio** sport addons, and **Forja Sports** — the same enabled **Catalog** JS schedule as Forja Live, matched to channels on your own Xtream portal. Browse by sport category, pick a match, and watch in the native IPTV player. Some third-party streams cannot be replayed in the native mpv player because their HLS URLs are session-bound.

## How to open it

Tap **Live Sports** in the navigation bar.

## What you can do

- Use the **Catalog** button (label shows **All**, **PPV**, **Streamed**, …) to filter the **schedule grid** — opening a match still resolves every enabled provider in **Providers** on the detail page, not just the selected catalog. A **schedule** button next to that opens one sheet with **Status** (**Airing** / **Upcoming** / **Airing + upcoming**) and **Horizon** (**1h** / **3h** / **6h** / **24h**).
- Switch sport category circles (centered on desktop and TV) when two or more sports are in the schedule — the row is hidden when only one category applies (e.g. football only). **24/7** covers always-on channels from catalogs that expose them (no schedule date — e.g. Willow Cricket, Tennis Channel, Rally TV). Those appear only on the 24/7 chip — hidden from All and from other sports (card grid and timeline) — and stay tappable as LIVE
- On **phone / desktop**, Live Matches uses **card view** only for now — the timeline view toggle is temporarily hidden.
- On **TV (Android TV / leanback)**, Live Matches is **cards only** — no timeline view and no view toggle. The server sheet lists **Forja Live**, **Forja Sports**, and **Stremio** when each is enabled in **Settings → Forja Sports → Setup** — not a trimmed TV-only set. A saved preference for a hidden server is clamped to the next available one; the IPTV **Portals** button appears on **Forja Sports**. Forja Live and Forja Sports cards share the green source badge (TimStreams, StreamFree, …); pick a catalog from the **Catalog** top-bar button (schedule grid only) and schedule Status/Horizon from the **schedule** button (**Airing** / **Upcoming** / **Airing + upcoming**, plus **1h**–**24h**). Opening a match pushes the **detail** page (hero + inline stream list under **Show Sources** / **Show Channels**); **Forja Live** engine unlock runs when you pick a stream. Every enabled provider for that event is listed — not scoped to the Catalog picker. **Forja Sports** shows Xtream-matched channels on the detail page. On non–Forja Live servers, **Forja Sports** and **Stremio** streams can both appear (Forja Sports first, then Stremio). Match and channel tiles are **landscape** (same continue-watching width, 16:9 art + title/league under — not square/portrait IPTV poster cells). Sport category circles are **centered** and scaled to fit when needed (same as Anime / Home mood rows); hidden when only one sport is loaded. D-pad moves **server → Catalog → schedule → Portals (Forja Sports) → Refresh → sport chips (when shown) → match cards**. **↑** from sport chips returns to the **Servers** button (or Catalog / schedule when those are shown — including after choosing **Stremio**); when sport chips are hidden, **↑** from the first card row goes straight to the top bar. Focused server / Catalog / schedule use the same brand-green focus chrome as **Portals**; focused **Refresh** turns white. Activating **Refresh** keeps D-pad focus on **Refresh** after the catalog reloads. Picking a server, catalog, or schedule option keeps focus on that top-bar button. Within the card grid, **←/→** stay on the current row (row ends do not wrap). **↑** from the first card row returns to sport chips when shown, then the schedule / Catalog / server buttons (not skipping past them). **←** from the left edge of a row returns to the nav rail. Empty lists autofocus **Refresh**. Entering the tab restores the last grid focus
- Browse upcoming and live events — live matches appear first. Only **live** matches are tappable and show the play button (green and floated upward, with a slowly pulsing play icon, on hover/focus). Upcoming cards still highlight and lift on hover in the timeline; they show the start time badge only. **Card view** shows start–finish (or kickoff only) above the match title when schedule data is available. Catalogs that report concurrent viewers (PPV, StreamFree, TimStreams, WatchFooty, …) show a viewer count on the card; when the same event is merged across catalogs, the counts are **added**. Merging treats PPV-style **Away at Home** and Streamed-style **Home vs Away** as the same fixture (team order / connector do not matter). Opening a live card always opens the stream picker — if nothing resolved, the panel says **No streams available** (cards do not show a separate “Not yet available” badge). The stream picker header totals viewers across every listed stream (per-stream when the source provides it, otherwise each catalog’s audience once); rows show the same. Card and timeline views refresh ● LIVE badges about once a minute while the tab is open.
- Open a **live** match to open its **detail** page — full-screen cinematic hero. Under the title, **Providers** and **Live TV** toggle which list shows on the hero:

  - **Providers** — Forja Live streams (PPV, Streamed, TimStreams, … from every enabled catalog provider) **plus** matching **Stremio** addon streams in one list.
  - **Live TV** — channels on your Xtream portal matched for this fixture (**Forja Sports** IPTV resolve).

  Rows load in parallel; tap a card to play in the native IPTV player. **Forja Live** resolves through the live sport plugin; on miss shows an error toast — never the site embed player. Back returns to the match grid.
- Back / Escape exits the player and **stops audio**. On **Android TV**, remote **Back** twice leaves; remote **Exit** is separate
- On **Android TV**, pressing **Home** (or switching to another app) **pauses** the live stream; returning to Forja resumes. Desktop can keep playing in the background.
- When a **Forja Live** match has several streams, the detail page lists them as cards — inline rows (e.g. PPV) appear at once; each catalog mirror resolves in parallel and **rows land as they arrive** (status shows **N found · still searching…** while more load). Dead listings are dropped. Tap a card to play in the native IPTV player; unlock on pick advances through **Unlocking source…**, **Preparing playback…**, and **Loading other servers…** when needed. On miss, a toast appears. Stream cards use the same flat movie **Sources** tile (fill + soft border on hover/focus, **HD** chip before the title, viewer count and provider on the right) — same for **Stremio** and **Forja Sports**. **Forja Live**, **Stremio**, and **Forja Sports** multi-source sessions in the native player share the same **Source** menu: the row that is playing shows **Playing**, scrolls into view when you open the menu, and on TV takes D-pad focus first (**↑/↓** / **OK** to switch)
- Double-click the video to enter/exit fullscreen on desktop. On **TV**, there is no fullscreen button — the player is already immersive
- Refresh lists for new events

## Tips

- Streams are third-party — availability changes with broadcasts and region
- Escape still backs out of the player on all platforms (and stops the stream)
- The **Stremio** server chip uses your saved Live assignment + sport catalogs on disk — opening Live Sports does not re-fetch every installed VOD addon first. Opening **Stremio** itself refreshes only Live-assigned addons.

## Related

- [IPTV — Xtream](iptv-xtream.md) — portals reused by **Forja Sports** matching
- [Forja Sports](../settings/forja-sports.md) — setup for Live Matches → Forja Sports (stream resolve + live plugin toggles)
- [Content hub scrapers](../scrapers/content-hub-scrapers.md)
