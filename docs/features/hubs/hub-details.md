# Hub details

> Pack-driven title page for Anime, Asian Drama, and other catalog hubs.

## What it is

When you open **View details** on a hub catalog card (or pick a result from the hub **Search** overlay), Forja loads the pack’s `details` action and renders shared **catalog-kit** chrome: cinematic hero, play row, episode picker, pack-owned rails, and optional TMDB enrich layered on top.

**IPTV Movies / Series** on the IPTV tab use the same kit via the IPTV hub pack (`details` on the hub plugin) — portal-only meta first, optional `iptv-enrich-tmdb` companion for TMDB match. Play stays on the portal stream.

Pack data (AniList, KissKH, …) stays primary; companion enrich plugins add backdrops, logos, and cast when a TMDB match exists. Anime **More Like This** comes from AniList. Asian Drama **More Like This** uses TMDB similarity resolved onto KissKH titles. The host does not fetch TMDB itself — enrich comes from the pack pipeline.

**TMDB movie/TV rows** in a hub (e.g. Asian Drama **Popular**) still open [TMDB details](../movies-tv/tmdb-details.md) when the card itself is stamped `open.surface: tmdb`. Hub **More Like This** on Anime / Asian Drama stays on that hub.

## How to open it

From **Home**, **Anime**, **Asian Drama**, **IPTV** (Movies / Series), or **My List**:

- Hero **View details** or a catalog poster
- Hub top-bar **Search** overlay — tap a result (not the archived Search nav tab)
- **Continue watching** on the hub tab
- **My List** poster — nav switches to the owning hub (Anime / Asian Drama / Home) while details is open
- IPTV **Movies** / **Series** tiles — same kit; episodes for series come from the IPTV pack `details` action (`meta.videos`)

## What you can do

- **Hero** — pack title, synopsis, meta, rotating backdrops (Ken Burns on desktop/mobile; static stills on Android TV). Packs may supply a clear title `logo` on meta; TMDB enrich may also add a title logo, extra facts, and richer backdrops without replacing pack art.
- **Play row** — green **Play** / **Resume** runs the hub play path (Megaplay / KissKH native / Forja Auto / webstreaming when enabled). White **Play** / **Resume** (link icon) opens **Sources** when Direct torrent / Stremio / Nuvio / Forja play sources are on — same panel chrome as [TMDB details](../movies-tv/tmdb-details.md). Catalog ids (`meta.ids` + enrich) drive Torrents (IMDb for Torrentio), Stremio (per-addon id prefixes), and Nuvio (TMDB only — skipped without a real TMDB match). Packs that set `open.torrentEp` get `Title 05`-style torrent search. **Trailer** appears when TMDB enrich returned videos (same in-app trailer player as movie/TV details). Titles with **no aired episode yet** (or `NOT_YET_RELEASED` / future premiere) show **Coming soon** with the premiere or earliest episode date instead of Play — future episode stubs alone do not unlock Play.
- **Episodes** — first body section under the hero (same spacing as pack rails). Select a season (multi-season franchises) or episode; hero **Play** applies to the selected episode. Home titles honor the Home pack **Episode list** setting on **Settings → Forja Packs** (**Cards** or **Number chips**). Each row shows its air date when the pack (or TMDB enrich) provides one — future dates appear in **orange** and cannot be played. Mark watched at ≥85% or via right-click / double-click on episode cards.
- **My List** — glass **+** with Plan to Watch / Watching / … (Simkl when connected and ids resolve).
- **Pack rails** — Related, recommendations, and other pack rails after enrich. Protocol **Cast / Characters**, **Crew**, and **Trailers** rows paint from `meta.cast` / `meta.crew` / `meta.trailers` (AniList Characters/Staff on Anime; TMDB enrich on Home / Asian Drama). Body order keeps Cast/Characters above More Like This. Related / More Like This posters show year (and type under the title when present) — not a FILM / TV corner chip. Anime and Asian Drama **More Like This** open another hub details page (AniList / KissKH), not Home TMDB. On **Android TV**, focused cast/crew circles get a white ring on the photo; focused body rows sit about **25%** down from the top (not flush to the edge); **↑** from Characters scrolls the page to the top and walks **episodes → seasons → Play → back**; films go **Play → back**.
- **Play filters** — when the pack’s `filters` action declares `play[]` grouped choices (e.g. SUB / DUB on Anime), they render on the details hero. The selection is stamped into Forja extract as `category` so providers scrape that lane only; green Play and Sources filter tagged rows the same way.
- **Resume / clear** — trash next to **Resume** clears watch progress and cached stream URLs for that title.

## Hub-specific play

| Hub | Default green Play | Notes |
|-----|-------------------|--------|
| **Anime** | Megaplay / VidNest / Miruro race (or Forja Auto when on) | AniList + MAL ids passed to providers; see [Anime](anime.md) tips for provider order |
| **Asian Drama** | KissKH native extract | Upcoming titles disable play until published |

Loading uses the shared cinematic resolve overlay (**Finding / Checking / Probing / Opening**). **Cancel**, leaving the page, or switching tabs stops in-flight checks.

## Tips

- Enrich cache is session-scoped — reopening the same title reuses TMDB match without a second wait.
- Anime / Asian Drama **More Like This** stays on that hub. Other TMDB-stamped rows still open [TMDB details](../movies-tv/tmdb-details.md).
- Playback, Sources panels in the player, and next-episode behavior match the main [Player](../playback/player.md) — hub titles use the same player shell as movies/TV.

## Related

- [Anime](anime.md) · [Asian Drama](asian-drama.md) — browse tabs
- [TMDB details](../movies-tv/tmdb-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
