# Anime

> Dedicated anime hub — discover, search, and multi-server playback.

## What it is

The Anime tab is a catalog hub from the ForjaHQ **Anime** pack plugin `anilist` (`kind: catalog`). **Browse rails** (hero, moods, trending, airing, …) are pack-defined; spotlight and details get TMDB enrich from companion plugin `anime-enrich-tmdb`. The shell renders the shared **cinematic hero**, host **Continue Watching**, and **Search** via the pack `search` action. Toggle the tab under **Settings → Features**.

Title pages use [Hub details](hub-details.md) (catalog kit), not the TMDB details screen.

## How to open it

Tap **Anime** in the navigation bar.

## What you can do

- Browse hero and mood-based rails — titles follow **Settings → Playback → Anime title language** (**Romaji** by default). The browse hero uses the **same cinematic carousel as Home**. On **desktop / TV**, a top menu overlays the hero: **Search**, **Films**, **Series**, **Categories** (AniList genres). Films/Series/Categories **refetch** the hub from AniList; under those filters **Trending** is hidden and the hero uses Top Rated. **Upcoming** / **Airing** statuses show in hero meta; unreleased titles show **Coming soon** above **View details**. Hero and catalog posters have a glass **+** (My List / Simkl when connected).
- **Continue watching** in-progress series — hover play on desktop; D-pad graph skips empty rows on TV.
- **Search** — hub top-bar **Search** (desktop / TV / mobile). Two-column layout on desktop/TV: search field, last searches + recommendations on the left, results grid on the right. Plain title search via the Anime pack (`search` capability — no structured person/year DSL unless the pack declares `structured_search`). **Cmd+F** / **Ctrl+F** opens or focuses search on desktop.
- **View details** on any card → [Hub details](hub-details.md) (episodes, SUB/DUB, play, Sources when TMDB matched). Details **SUB** / **DUB** is passed into Forja extract so providers scrape that lane; green Play races only matching streams.
- **Torrents in Sources** — same panel as movies/TV; the Anime pack sets `open.torrentEp` so search uses `Title 05`, and Torrentio runs when enrich supplied an IMDb id (see [Torrent scrapers](../scrapers/torrent.md)).
- **Pick your vibe** — same circular mood icons as Home; D-pad **↑** from mood posters returns to vibes.

## Tips

- On **desktop**, drag-select hub and details hero titles to copy them.
- Hero paints from AniList in parallel; TMDB backdrops + logo swap in when enrich returns (English title match, season suffixes stripped).
- Reorder sources under **Settings → Playback → Anime provider order** — default starts with **Megaplay**, then pinned **AniKoto**, VidNest / AllAnime, **VidLink** (MAL + webstreaming), Miruro pipes.
- **Megaplay** uses AniList id (+ MAL when mapped) — no Anikoto title remap. **VidLink** needs MAL via Jikan; skipped on Android TV unless WebView override is on.
- Forja Auto green Play races the full category provider pool (same as movies/TV; session cache shared with Sources → Forja). Panel chips do not narrow green Play.
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Hub details](hub-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
