# IPTV — Stalker

> Connect Stalker / Ministra portals (MAC) — live TV, movies, and series.

## What it is

The IPTV tab supports **Stalker / Ministra** portals alongside Xtream and M3U. You add a portal URL and device MAC, then browse Live / Movies / Series in the same catalog as Xtream. Streams are resolved with `create_link` when you play (links expire).

## How to open it

**IPTV** → **Portals** → **Add** → choose **Stalker**.

## What you can do

- Add a Stalker portal with URL (often ending in `/c/` or `portal.php`) and MAC (`00:1A:79:…`); optional serial
- Tap **Generate** next to the MAC field for a random MAG-style MAC if your provider issues portal access by any MAC
- Browse **Live**, **Movies**, and **Series** like Xtream
- Play in the IPTV player — channel guide and search work for live
- Sync Stalker portals to your signed-in profile (same as Xtream)

## Setup

1. Get the portal URL and a permitted MAC from your provider (or generate one with the **Generate** button)
2. **Portals** → **Add** → **Stalker** → fill URL and MAC → confirm
3. Open the portal from the list

Forja tries the common middleware paths automatically (`portal.php`, `server/load.php`, `stalker_portal/server/load.php`) — pasting `/c/`, a bare host, or the full `.php` path all work.

## Tips

- Programme guide (EPG) for Stalker is not wired yet — Live cards skip Xtream EPG calls
- Deal / Find Portals still focus on Xtream pool portals; add Stalker manually for now
- MACs are stored like usernames; keep share codes and CSV exports private
- First open can take a moment on flaky portals (Cloudflare 520 / origin 502) — Forja retries handshake and catalog fetch automatically before showing an error

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [IPTV — M3U](iptv-m3u.md)
- [Player](../playback/player.md)
