# Forja Sports

> Play Live Matches cards using channels on your Xtream portal.

## What it is

On-device Sports matcher (Sportio-style): the **same** enabled **Catalog** JS schedule as **Forja Live** / **All** (TimStreams, StreamFree, ESPN, PPV, Streamed, …), then name/EPG matching against live channels on **one** Xtream portal. Streams play in the native IPTV player. No self-hosted addon. Not an ESPN-only grid.

**Forja Sports** is enabled by default with all leagues matched. **Settings → Forja Sports** (admin accounts only) can change leagues, live plugins, and catalog toggles.

## How to open it

- **Live Matches → Servers → Forja Sports** (portal via top-right **Portals**)
- **Settings → Forja Sports** (admin) for leagues and live plugin toggles

## What you can do

- **Forja plugins** — built-in pack expansion with per-plugin toggles (Streamed, PPV, TimStreams, StreamFree, WatchFooty, Streamic, …).
- **Catalog** — schedule toggles (Streamed, PPV, TimStreams, StreamFree, WatchFooty, Streamic, ESPN). Checked catalogs appear as chips on Live Matches **All**, **Forja Live**, and **Forja Sports**, and load the same schedule rows. **Live plugins** toggles are for stream resolve only.
- Browse the same catalog schedule as Forja Live, **merged with ESPN** when **Catalog → ESPN** is on (clean home/away for matching; ESPN-only games still appear)
- Pick the Xtream portal from top-right **Portals** (same IPTV panel)
- Open a match → right-side panel opens immediately while Forja sniffs your portal; ranked channels appear as they land (logo, short name, category, tier badge) → pick one to play (failover keeps the rest in the player Source menu with the same layout). Re-opening the same match within **30 minutes** reuses the last match result (no second portal search)
- In-player **programme guide** — with **Settings → Playback → IPTV programme guide (EPG)** on, the native player shows the same floating card as IPTV Live (LIVE / NEXT / LATER, progress bar, description) for the active channel
- Choose which leagues to match in Settings (admin; on Android TV, D-pad **↓** through league chips scrolls through the last sport)

## Setup

1. Add an Xtream portal under IPTV (if you don’t have one)
2. Live Matches → Servers → **Forja Sports** → top-right **Portals** if needed
3. Optional (admin): Settings → Forja Sports to narrow leagues or tune live plugins

## Tips

- Catalog = same enabled Catalog JS as Forja Live / All, plus ESPN enrichment when that catalog is on — ESPN supplies team names for Xtream match; the catalog grid drives the cards
- Portal is only in Live Matches / IPTV Portals (not Settings)
- Matching tokenizes the event title, teams, and sport chip, then scores **channel name**, **Xtream folder name**, and **short EPG** (no hardcoded venue/sport alias lists)
- Channel match results are remembered for **30 minutes** per match and portal when channels were found (app restart clears them); **no channels** is retried on the next open
- No channels on deck after retry means the portal had no channel name/EPG hit for that game
- Live Matches stream resolve uses **Engine** (native player) by default on **Forja Live**; the mode pill next to **Servers** shows **Sniff** or **Engine** there (admin can switch in Settings → Forja Sports). **Forja Sports** shows **IPTV**; **Stremio** shows **Stremio**.

## Related

- [Live Matches](../live/live-matches.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
