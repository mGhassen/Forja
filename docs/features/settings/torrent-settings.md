# Torrent settings

> Providers, cache, connections, and sort order.

## What it is

Controls how torrent search and the torrent engine behave: which built-in providers to query, result sort order, **disk cache size**, and peer connection limits. **Forja plugins**, Stremio / Nuvio addons, and Jackett / Prowlarr indexers are configured here too.

## How to open it

**Settings → Sources**

## What you can do

- Manage **Forja plugins** (first on the page) — first open of Sources → Forja selects enabled plugins for the current media category (Movie on movies, TV on series); Anime / Drama plugins stay available from Filters → Category. Expand a pack and use tabs **Movie & TV** / **Anime** / **Drama** / **Hubs** (one list at a time). The **Live Sports** pack uses **Catalog** / **Provider** tabs — one toggle per site in each tab (schedule vs stream resolve). **Installed packs** are grouped by kind: **Providers**, **Live**, **Hubs** (Home / Anime / Asian Drama / Arabic), then community **Other** — each row shows the kind (and hub slot when relevant), manifest URL, plugin count · version. Every HTTP plugin plus hub `kind: catalog` plugins are listed — hops stay internal. The list opens from local cache immediately; install / refresh from the network continues in the background. Paste a `manifest.json` URL under **Add plugin** (or sync pack rows from your signed-in profile / web **Profile → Forja plugins**); lean cloud rows hydrate on first use. When a remote pack `version` is newer than the installed one, that pack can refresh once per session. The same plugin id in two packs is refused. Each pack row has a switch to enable or disable every listed plugin at once; expand for per-plugin toggles. Use **Refresh** / **Remove** per pack. Scripts are cached per pack so packs do not overwrite each other. Each HTTP plugin keeps API bases, mirrors, proxies, and keys in a **SPECS** block inside its script (not in the pack manifest). The manifest stays identity/routing (`id`, `entry`, `types`, `hosts`, …); a small `config` bag remains only when one script serves multiple plugins (e.g. anime server lists, hop decrypt names) or a live sport plugin needs unlock keys. **Admin → Providers** remote JSON can still overlay `engine.<pluginId>` keys at runtime (nested maps merge; mirror lists replace) without reinstalling the pack. **Videasy** probes every [player.videasy.to](https://player.videasy.to) server (Yoru, Cypher, Breach, Neon, Vyse, Killjoy, Fade, Omen, Raze) and lists each hit as its own row. When a mirror only returns an HLS master, Forja expands it into 1080p / 720p / 480p rows (same card as Nuvio: title + episode + year, quality badges when the playlist has them).
- Install **Stremio** / **Nuvio** addons when those play sources are on (Stremio rows: switch next to trash enables/disables without uninstall; Sources / Live Matches chips assign surfaces); configure **Jackett** / **Prowlarr** when **Direct torrent** is on (**admin** only — green sparkles)
- Enable or disable each **torrent indexer** in **ForjaHQ Torrent** under Settings → Sources → Forja (expand the pack, toggle per plugin). Until that pack is installed, **Torrent search** shows an install hint. Enabled indexers show as chips under **Sources → Torrents** (plus **All**) when **Direct torrent** is on and built-in torrent search is available on this platform. Paired LAN clients search on-device via the same pack (the desktop LAN server only streams magnets, it does not run indexers).
- Set **sort preference** (e.g. seeders high to low)
- Set **disk cache** size (1–16 GB) — oldest idle torrent files are deleted when over this cap; the title you are playing is never removed — on **TV**, focus the slider and use **Left/Right**
- Set **connection limit** for the torrent engine — same D-pad nudge on **TV**

## Tips

- Disable providers you don’t use to speed up search. Rows still appear as each remaining provider returns — a slow one no longer holds the list empty.
- Lower the disk cache size on phones or small SSDs if space is tight
- Sort by seeders for fastest starts on [torrent playback](../playback/torrent-playback.md)
- On **Android TV**, **Lists**, **Data & backup**, and **Debrid** stay hidden. Configure torrents / Stremio / Nuvio / Forja under **Settings → Sources** on the TV the same as phone/desktop

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Stream providers](../sources/stream-providers.md)
- [Playback settings](playback-settings.md)
- [Debrid](../sources/debrid.md)
