# Forja Sports

> Play Live Matches cards using channels on your Xtream or Stalker portal.

## What it is

On-device Sports matcher (Sportio-style): the **same** enabled **Catalog** JS schedule as **Forja Live** / **All** (TimStreams, StreamFree, ESPN, PPV, Streamed, …), then name/EPG matching against live channels on **one** Xtream or Stalker portal. Streams play in the native IPTV player. No self-hosted addon. Not an ESPN-only grid.

**Forja Sports** is enabled by default with all leagues matched. **Settings → Forja Sports** can change leagues, live plugins, and catalog toggles — but only when Live / Catalog HTTP plugins are installed (otherwise the page is empty; install packs under **Settings → Sources → Forja**).

## How to open it

- **Live Matches → Servers → Forja Sports** (portal via top-right **Portals**)
- **Settings → Forja Sports** for leagues and live plugin toggles (empty until Live/Catalog packs are installed)

## What you can do

- **Live plugins** — per-pack toggles for stream resolve (Streamed, PPV, TimStreams, StreamFree, WatchFooty, Streamic, …). Packs are installed under **Settings → Sources → Forja**.
- **Catalog** — schedule toggles (Streamed, PPV, TimStreams, StreamFree, WatchFooty, Streamic, ESPN). **Default on:** Streamed, PPV, StreamFree — others off until you enable them. Checked catalogs appear as chips on Live Matches **All**, **Forja Live**, and **Forja Sports**, and load the same schedule rows. **Live plugins** toggles are for stream resolve only.
- Browse the same catalog schedule as Forja Live, **merged with ESPN** when **Catalog → ESPN** is on (clean home/away for matching; ESPN-only games still appear). Switching **Servers** between Forja Live and Forja Sports keeps that list — no reload
- Pick an **Xtream** or **Stalker** portal from top-right **Portals** (same IPTV panel; M3U is not supported for Sports yet)
- Open a match → right-side panel opens immediately while Forja sniffs your portal; ranked channels appear as they land (logo, short name, category, tier badge, **NOW/NEXT EPG** when the portal provides listings) → pick one to play (failover keeps the rest in the player Source menu with the same layout). Re-opening the same match within **30 minutes** reuses the last match result (no second portal search)
- In-player **programme guide** — with **Settings → Playback → IPTV programme guide (EPG)** on, the native player shows the same floating card as IPTV Live (LIVE / NEXT / LATER, progress bar, description) for the active channel (Xtream `player_api` or Stalker MAG EPG)
- Choose which leagues to match in Settings (on Android TV, D-pad ←/→ between league chips and ↓ through the last sport)

## Setup

1. Add an Xtream or Stalker portal under IPTV (if you don’t have one)
2. Live Matches → Servers → **Forja Sports** → top-right **Portals** if needed
3. Optional: Settings → Forja Sports to narrow leagues or tune live plugins

## Tips

- Catalog = same enabled Catalog JS as Forja Live / All, plus ESPN enrichment when that catalog is on — ESPN supplies team names for portal match; the catalog grid drives the cards
- Portal is only in Live Matches / IPTV Portals (not Settings)
- Matching tokenizes the event title, teams, and sport chip, then scores **channel name**, **folder/genre name**, and **short EPG** (no hardcoded venue/sport alias lists). For team sports, name hits are preferred for EPG lookups; if few/none mention the teams, Forja still short-EPGs up to **120** channels in your mapped folders so programme titles on ESPN / beIN / etc. can match
- Channel match results are remembered for **30 minutes** per match and portal when channels were found (app restart clears them); **no channels** is retried on the next open
- **Stalker:** matched rows keep the channel cmd (not a play URL). Forja calls `create_link` only for the channel you pick (failover channels mint on switch) — links expire, so they are not cached as durable URLs. Short EPG matching uses the Mag channel id (`epg_channel_id`, or digits from the cmd) — same as IPTV Live
- No channels on deck after retry means the portal had no channel name/EPG hit for that game
- Live Matches stream resolve uses **Engine** (native player) by default on **Forja Live**; the mode pill next to **Servers** shows **Sniff** or **Engine** there (switch in Settings → Forja Sports). **Forja Sports** shows **IPTV**; **Stremio** shows **Stremio**.

## Related

- [Live Matches](../live/live-matches.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
- [IPTV — Stalker](../live/iptv-stalker.md)
