# Torrent settings

> Providers, cache, connections, sort order, and webstreaming server reliability.

## What it is

Controls how torrent search and the torrent engine behave: which built-in providers to query, result sort order, **disk cache size**, and peer connection limits. When **Webstreaming** is on, this category also holds **Server reliability** (extractor order / Score / Tries).

## How to open it

**Settings → Sources**

## What you can do

- Manage **Forja plugins** (first on the page) — first open of Sources → Forja selects enabled plugins for the current media category (Movie on movies, TV on series); Anime / Drama plugins stay available from Filters → Category. Expand a pack and use tabs **Movie & TV** / **Anime** / **Drama** / **Live** / **Catalog** (one list at a time). **All installed packs** show here (Providers, Live, Catalog, and community) with every HTTP plugin — hops stay internal. **ForjaHQ Providers / Live / Catalog** auto-install on first launch and refresh when a remote version is newer; paste another `manifest.json` URL under **Add plugin** for community packs (same plugin id in two packs is refused). Community pack URLs also sync via the web portal under **Profile → Forja plugins** (before Stremio addons). Each pack row shows the **manifest URL** under the name (plus plugin count · version), a switch to enable or disable every listed plugin at once; expand for per-plugin toggles. Use **Refresh** / **Remove** per pack. Scripts are cached per pack so packs do not overwrite each other. Each HTTP plugin keeps API bases, mirrors, proxies, and keys in a **SPECS** block inside its script (not in the pack manifest). The manifest stays identity/routing (`id`, `entry`, `types`, `hosts`, …); a small `config` bag remains only when one script serves multiple plugins (e.g. anime server lists, hop decrypt names) or a live catalog needs `providerId`. **Admin → Providers** remote JSON can still overlay `engine.<pluginId>` keys at runtime (nested maps merge; mirror lists replace) without reinstalling the pack. **Videasy** probes every [player.videasy.to](https://player.videasy.to) server (Yoru, Cypher, Breach, Neon, Vyse, Killjoy, Fade, Omen, Raze) and lists each hit as its own row. When a mirror only returns an HLS master, Forja expands it into 1080p / 720p / 480p rows (same card as Nuvio: title + episode + year, quality badges when the playlist has them).
- Install **Stremio** / **Nuvio** addons when those play sources are on; configure **Jackett** / **Prowlarr** when **Direct torrent** is on (**admin** only — green sparkles)
- Reorder **Server reliability** when **Webstreaming** is on — Movies, Series, Anime, and Asian Drama: drag (desktop) or **↓/↑** between server names on TV; tap or **OK** a row to turn a server on or off; **Reset order** restores defaults
- Enable or disable each **torrent provider** (Knaben, The Pirate Bay, UIndex, Torrents CSV, Nyaa, YTS, SolidTorrents, TheRARBG, Torrentio) — enabled ones show as chips under **Sources → Torrents** (plus **All**) — only when **Direct torrent** is on and built-in torrent search is available on this platform
- Set **sort preference** (e.g. seeders high to low)
- Set **disk cache** size (1–16 GB) — oldest idle torrent files are deleted when over this cap; the title you are playing is never removed — on **TV**, focus the slider and use **Left/Right**
- Set **connection limit** for the torrent engine — same D-pad nudge on **TV**

## Tips

- **Server reliability**: tabs for Movies / Series / Anime / Asian Drama (one list at a time). Drag (desktop) or **↓/↑** between server names on TV; tap or **OK** a row to turn a server on or off (**green dot** = on, **red dot** = off). **Score** rises when a check **finishes** with linked server+stream outcomes (extract+stream OK → +4; extract OK but streams dead → net 0; never below **0**). Cancel / extract-only does not add a lone +2. **Tries** (1st, 2nd, …) is the order Auto tries **enabled** servers. Asian Drama keeps one KissKH mirror active at minimum; playback uses the first enabled mirror only (no auto-failover). In the player Source panel, the **badge number** is the same Score; **+/−** prefixes are this film/episode only (see [Stream providers](../sources/stream-providers.md)). Stream quality (codec, resolution, latency) is scored **after** resolve.
- Disable providers you don’t use to speed up search. Rows still appear as each remaining provider returns — a slow one no longer holds the list empty.
- Lower the disk cache size on phones or small SSDs if space is tight
- Sort by seeders for fastest starts on [torrent playback](../playback/torrent-playback.md)
- On **Android TV**, **WebStreamr**, **Lists**, **Data & backup**, and **Debrid** stay hidden; **Server reliability** stays phone/desktop (admin). Configure torrents / Stremio / Nuvio / Forja under **Settings → Sources** on the TV the same as phone/desktop

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Stream providers](../sources/stream-providers.md)
- [Playback settings](playback-settings.md)
- [Debrid](../sources/debrid.md)
