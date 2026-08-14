# Torrent settings

> Providers, cache, connections, sort order, and webstreaming server reliability.

## What it is

Controls how torrent search and the torrent engine behave: which built-in providers to query, result sort order, RAM vs disk cache, cache size, and peer connection limits. When **Webstreaming** is on, this category also holds **Server reliability** (extractor order / Score / Tries).

## How to open it

**Settings → Sources**

## What you can do

- Reorder **Server reliability** when **Webstreaming** is on — Movies, Series, and Anime: drag preference (desktop) or **↑/↓** (TV); **Reset order** is D-pad focusable on TV; **Score** is live reliability; **Tries** is Auto check order. Asian Drama currently keeps one KissKH host enabled and shows the others **On hold**
- Enable or disable each **torrent provider** (Knaben, The Pirate Bay, UIndex, Torrents CSV, Nyaa, YTS, SolidTorrents, TheRARBG, Torrentio) — enabled ones show as chips under **Sources → Torrents** (plus **All**) — only when **Direct torrent** is on and built-in torrent search is available on this platform
- Set **sort preference** (e.g. seeders high to low)
- Choose **cache type**: RAM or disk
- Adjust **RAM cache size** (MB) when using RAM cache — on **TV**, focus the slider and use **Left/Right**
- Set **connection limit** for the torrent engine — same D-pad nudge on **TV**
- Install **Stremio** / **Nuvio** addons and configure Jackett / Prowlarr when those play sources are on (never on Android TV for torrent/Stremio/Nuvio)

## Tips

- **Server reliability**: tabs for Movies / Series / Anime / Asian Drama (one list at a time). Drag (desktop) or **↑/↓** (TV) to prefer a server where ordering is enabled. **Score** rises when a check **finishes** with linked server+stream outcomes (extract+stream OK → +4; extract OK but streams dead → net 0; never below **0**). Cancel / extract-only does not add a lone +2. **Tries** (1st, 2nd, …) is the order Auto tries them. Asian Drama enables only `kisskh.nl`; `.co`, `.ovh`, `.la`, and `.do` remain visible as **On hold** and cannot be reordered, preventing automatic mirror checks from triggering KissKH's shared-IP rate limit. In the player Source panel, the **badge number** is the same Score; **+/−** prefixes are this film/episode only (see [Stream providers](../sources/stream-providers.md)). Stream quality (codec, resolution, latency) is scored **after** resolve.
- Disable providers you don’t use to speed up search. Rows still appear as each remaining provider returns — a slow one no longer holds the list empty.
- Higher RAM cache smooths playback on fast connections
- Disk cache helps on memory-constrained devices with large files
- Sort by seeders for fastest starts on [torrent playback](../playback/torrent-playback.md)
- On **Android TV**, Sources / WebStreamr / Lists / Data & backup / Debrid stay hidden; configure server order and torrent tools on phone or desktop

## Related

- [Torrent scrapers](../scrapers/torrent.md)
- [Torrent playback](../playback/torrent-playback.md)
- [Stream providers](../sources/stream-providers.md)
- [Playback settings](playback-settings.md)
- [Debrid](../sources/debrid.md)
