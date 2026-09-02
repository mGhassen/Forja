# Torrent settings

> Forja addons: Direct torrent, Stremio, Nuvio, indexers, and torrent engine.

## What it is

**Settings → Sources** covers **Forja addons** — playback toggles and install UI for **Direct torrent**, **Stremio**, and **Nuvio**, plus Jackett / Prowlarr (admin) and torrent search / engine prefs. **Forja JS plugin packs** (providers, hubs, live, …) moved to **[Forja Packs](forja-packs.md)**.

## How to open it

**Settings → Sources**

## What you can do

- **Forja addons** group — P2P disclaimer, then toggles for **Direct torrent**, **Stremio**, and **Nuvio** (platform caps apply on Android TV / LAN)
- Install **Stremio** / **Nuvio** addons (Stremio rows: switch next to trash enables/disables without uninstall; Sources / Live Matches chips assign surfaces)
- Configure **Jackett** / **Prowlarr** when **Direct torrent** is on (**admin** only — green sparkles)
- Enable or disable each **torrent indexer** in **ForjaHQ Torrent** under **Settings → Forja Packs** (expand the pack, toggle per plugin). Until that pack is installed, **Torrent search** shows an install hint. Enabled indexers show as chips under **Sources → Torrents** (plus **All**) when **Direct torrent** is on and built-in torrent search is available on this platform.
- Set **sort preference** (e.g. seeders high to low)
- Set **FlareSolverr / Byparr URL** when you use **UIndex** — `uindex.org` is Cloudflare-protected; point at a local solver (`http://127.0.0.1:8191`, same API as Prowlarr indexers)
- Set **disk cache** size (1–16 GB) — oldest idle torrent files are deleted when over this cap; the title you are playing is never removed — on **TV**, focus the slider and use **Left/Right**
- Set **connection limit** for the torrent engine — same D-pad nudge on **TV**

## Tips

- Disable providers you don’t use to speed up search. Rows still appear as each remaining provider returns — a slow one no longer holds the list empty.
- Lower the disk cache size on phones or small SSDs if space is tight
- Sort by seeders for fastest starts on [torrent playback](../playback/torrent-playback.md)
- On **Android TV**, **Lists**, **Data & backup**, and **Debrid** stay hidden. Configure **Forja addons** under **Settings → Sources** and packs under **Forja Packs** on the TV the same as phone/desktop

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Stream providers](../sources/stream-providers.md)
- [Playback settings](playback-settings.md)
- [Debrid](../sources/debrid.md)
