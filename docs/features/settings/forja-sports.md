# Forja Sports

> Play Live Matches cards using channels on your Xtream portal.

## What it is

On-device Sports matcher (Sportio-style): the **same** Live Matches schedule as **All** (PPV · Streamed · CDN), then name/EPG matching against live channels on **one** Xtream portal. Streams play in the native IPTV player. No self-hosted addon. Not an ESPN-only grid.

## How to open it

- **Live Matches → Servers → Forja Sports** (portal via top-right **Portals**)
- **Settings → Forja Sports** for Enable / leagues

## What you can do

- **Stream resolve** — **Sniff** (embed WebView player, default) or **Engine** (Forja live plugins → native player when GOAT unlock succeeds; otherwise opens the embed player). Dropdown under **Live stream resolve**; a **Sniff** / **Engine** pill on Live Matches mirrors the choice.
- **Forja plugins** — built-in pack expansion with per-plugin toggles (Streamed, PPV, TimStreams, StreamFree, WatchFooty, Streamic, …).
- **Catalog** — separate group below **Live plugins** for schedule feeds (TimStreams, StreamFree, …). **ESPN** toggle here gates the Rust scoreboard merge (same data as Forja Sports), not a separate JS fetch.
- Browse the same sports catalog as All, **merged with ESPN** for the same day (clean home/away for matching; ESPN-only games still appear)
- Pick the Xtream portal from top-right **Portals** (same IPTV panel)
- Open a match → right-side panel opens immediately while Forja sniffs your portal; ranked channels appear as they land (logo, short name, category, tier badge) → pick one to play (failover keeps the rest in the player Source menu with the same layout). Re-opening the same match within **30 minutes** reuses the last match result (no second portal search)
- In-player **programme guide** — with **Settings → Playback → IPTV programme guide (EPG)** on, the native player shows the same floating card as IPTV Live (LIVE / NEXT / LATER, progress bar, description) for the active channel
- Choose which leagues to match in Settings

## Setup

1. Add an Xtream portal under IPTV (if you don’t have one)
2. Live Matches → Servers → **Forja Sports** → top-right **Portals** if needed
3. Optional: Settings → Forja Sports to enable and pick leagues

## Tips

- Catalog = All (PPV · Streamed · CDN) **plus ESPN** for configured leagues — ESPN supplies team names for Xtream match; All still drives the grid
- Portal is only in Live Matches / IPTV Portals (not Settings)
- Matching tokenizes the event title, teams, and sport chip, then scores **channel name**, **Xtream folder name**, and **short EPG** (no hardcoded venue/sport alias lists)
- Channel match results are remembered for **30 minutes** per match and portal when channels were found (app restart clears them); **no channels** is retried on the next open
- No channels on deck after retry means the portal had no channel name/EPG hit for that game

## Related

- [Live Matches](../live/live-matches.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
