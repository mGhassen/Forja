# IPTV — Stalker

> Connect Stalker / Ministra portals (MAC) — live TV, movies, series, and EPG.

## What it is

The IPTV tab supports **Stalker / Ministra** portals alongside Xtream and M3U. You add a portal URL and device MAC, then browse Live / Movies / Series in the same catalog as Xtream. Streams are resolved with `create_link` when you play (links expire).

## How to open it

**IPTV** → **Portals** → **Add** → choose **Stalker**.

## What you can do

- Add a Stalker portal with URL (often ending in `/c/` or `portal.php`) and MAC (`00:1A:79:…`); optional serial
- Tap the dice icon next to the portal name field for a random name
- Tap **Generate** next to the MAC field for a random MAG-style MAC if your provider issues portal access by any MAC
- Browse **Live**, **Movies**, and **Series** like Xtream — movies and series open the same Home-style details overlay (portal first; TMDB layers in when matched — logo, production card, Cast/Crew/Trailers; series also get episodes; Android TV D-pad matches movie details)
- View programme guide (EPG) when the portal provides it — Live cards show **NOW** / **NEXT**, long-press opens the programme sheet, the in-player guide peeks listings, and the desktop Live **EPG** grid uses the same data (same Settings toggle as Xtream)
- Play in the IPTV player — channel guide and search work for live
- Use the portal with **Live Matches → Forja Sports** (name/EPG match; stream link created when you pick a channel)
- Sync Stalker portals to your signed-in profile (same as Xtream)
- See subscription end date on the portal card when known (scrape/manual or `get_profile` `exp_date` / date-like `phone`); if a status probe returns no date, a known date stays with a trailing `*` instead of flipping to **Ends: Unknown**

## Setup

1. Get the portal URL and a permitted MAC from your provider (or generate one with the **Generate** button)
2. **Portals** → **Add** → **Stalker** → fill URL and MAC → confirm
3. Open the portal from the list

Forja tries the common middleware paths automatically (`portal.php`, `server/load.php`, `stalker_portal/server/load.php`) — pasting `/c/`, a bare host, or the full `.php` path all work.

## Tips

- Live channel green/red borders follow a real open (same idea as play) — if a channel plays, hover should not stay red after you update the app
- Hot-restart after an engine update so Stalker EPG is loaded; guide ids are taken from `stream=` in the play cmd when needed (no catalog reload required)
- Not every Stalker panel ships EPG — empty NOW/NEXT means the portal returned no listings
- Deal / Find Portals still focus on Xtream pool portals; add Stalker manually for now
- MACs are stored like usernames; keep share codes and CSV exports private
- First open can take a moment on flaky portals (Cloudflare 520 / origin 502) — Forja retries handshake and catalog fetch automatically before showing an error
- Not every portal returns an end date — those show **Ends: Unknown**; a trailing `*` means the date came from scrape/manual and login did not confirm it

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [IPTV — M3U](iptv-m3u.md)
- [Forja Sports](../settings/forja-sports.md)
- [Player](../playback/player.md)
