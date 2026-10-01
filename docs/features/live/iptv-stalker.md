# IPTV — Stalker

> Connect Stalker / Ministra portals (MAC) — live TV, movies, and series.

## What it is

The **IPTV hub pack** supports **Stalker / Ministra** portals alongside Xtream and M3U. Add a portal URL and device MAC, then browse Live / Movies / Series in pack layout. Streams resolve with `create_link` when you play.

## How to open it

**IPTV** → **Portals** → **Add** → choose **Stalker** (or **Settings → Addons → IPTV** → Platform **Stalker / MAG**).

## What you can do

- Add a Stalker portal with URL and MAC (`00:1A:79:…`); optional serial
- Browse **Live**, **Movies**, and **Series** in the pack kit — movies/series open hub details (portal meta; optional TMDB enrich; series episodes from pack `details`)
- Play in the IPTV player — channel guide and search for live; each open mints a fresh `create_link`
- Use the portal with **Live Sports → Forja Sports** when that toggle is on

## Setup

1. Get the portal URL and a permitted MAC from your provider
2. **Portals → Add** → **Stalker** → fill URL and MAC → save
3. Select the portal from the list

## Tips

- Common middleware paths (`portal.php`, `server/load.php`, …) are tried automatically
- Deal / Find Portals still focus on Xtream pool portals — add Stalker manually
- MACs are stored like usernames; keep share codes and CSV exports private

## Related

- [IPTV — Xtream](iptv-xtream.md)
- [IPTV — M3U](iptv-m3u.md)
