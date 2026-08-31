# Asian Drama

> Asian dramas and shows via KissKH.

## What it is

Asian Drama is a catalog hub from the ForjaHQ **Asian Drama** pack plugin `kisskh-hub` (`kind: catalog`). **Browse rails** are pack-defined; spotlight and details get TMDB enrich from companion plugin `enrich-tmdb`. The shell renders the shared **cinematic hero**, host **Continue Watching**, and **Search** via the pack `search` action. Toggle the tab under **Settings → Features**.

KissKH title pages use [Hub details](hub-details.md). The **Popular** row is TMDB Asian TV — those cards open [TMDB details](../movies-tv/tmdb-details.md).

## How to open it

Tap **Asian Drama** in the navigation bar.

## What you can do

- Browse hero and explore sections — cards use **wide 16:9** KissKH banners. Top menu: **Search**, **Films**, **Series**, **Categories** (country filters). Films/Series/country **refill KissKH rails** (Latest, Trending, …). **Popular** is TMDB-only (opens TMDB details). **Upcoming** shows **Coming soon** in hero meta when KissKH marks a title unreleased.
- **Search** — hub top-bar **Search** overlay (same two-column pattern as Anime on desktop/TV). Plain KissKH title search via the pack `search` action (no structured DSL unless the pack declares `structured_search`). **Cmd+F** / **Ctrl+F** on desktop.
- **View details** on KissKH cards → [Hub details](hub-details.md) (episodes, KissKH native play, Sources when TMDB matched).
- **Continue watching** — resume from hub row or details; clear progress with trash on details hero.
- Order KissKH mirrors under **Settings → Sources → Server reliability → Asian Drama** — playback uses the first enabled mirror only (no auto-failover across aliases).

## Tips

- On **desktop**, drag-select hero titles to copy them.
- KissKH posters often use TMDB CDN; Android 7.0 builds embed Let's Encrypt roots for those hosts.
- Stream resolve signs KissKH keys in-engine (~1s typical); WebView fallback only if direct path fails. Rate-limit cooldown does not hop mirrors.
- KissKh play uses the site’s **Sub API** subtitles (decrypted) — not the HLS mux tracks alone, which can be out of sync with the website player.
- **Escape** / **Cancel** during resolve returns to details; leaving the tab stops the extract.
- Part of [content hub scrapers](../scrapers/content-hub-scrapers.md)

## Related

- [Hub details](hub-details.md)
- [Anime](anime.md)
- [TMDB details](../movies-tv/tmdb-details.md)
