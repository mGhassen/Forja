# Hub details

> Pack-driven title page for Anime, Asian Drama, and other catalog hubs.

## What it is

When you open **View details** on a hub catalog card (or pick a result from the hub **Search** overlay), Forja loads the pack’s `details` action and renders shared **catalog-kit** chrome: cinematic hero, play row, episode picker, pack-owned rails, and optional TMDB enrich layered on top.

**IPTV VOD** (Movies / Series on the IPTV tab) uses the same kit via the **IPTV VOD** catalog pack (`types: iptv`) — portal-only meta first, optional `iptv-enrich-tmdb` companion for TMDB match. Play stays on the portal stream.

Pack data (AniList, KissKH, …) stays primary; companion enrich plugins add backdrops, logos, cast, and **More Like This** when a TMDB match exists. The host does not fetch TMDB itself — enrich comes from the pack pipeline.

**TMDB movie/TV rows** in a hub (e.g. Asian Drama **Popular**) still open [TMDB details](../movies-tv/tmdb-details.md), not this screen.

## How to open it

From **Home**, **Anime**, or **Asian Drama**:

- Hero **View details** or a catalog poster
- Hub top-bar **Search** overlay — tap a result (not the archived Search nav tab)
- **Continue watching** on the hub tab

## What you can do

- **Hero** — pack title, synopsis, meta, rotating backdrops (Ken Burns on desktop/mobile; static stills on Android TV). TMDB enrich may add a title logo, extra facts, and richer backdrops without replacing pack art.
- **Play row** — green **Play** / **Resume** runs the hub play path (Megaplay / KissKH native / Forja Auto / webstreaming when enabled). White **Play** / **Resume** (link icon) opens **Sources** when TMDB matched and Direct torrent / Nuvio / Forja play sources are on — same panel chrome as [TMDB details](../movies-tv/tmdb-details.md). **Trailer** appears when TMDB enrich returned videos (same in-app trailer player as movie/TV details).
- **Episodes** — select a season (multi-season franchises) or episode; hero **Play** applies to the selected episode. Mark watched at ≥85% or via right-click / double-click on episode cards.
- **My List** — glass **+** with Plan to Watch / Watching / … (Simkl when connected and ids resolve).
- **Pack rails** — Characters, Staff, Related, Trailers, recommendations — whatever the pack returns after enrich.
- **Anime only** — **SUB** / **DUB** toggle before play; filters Sources and provider resolve.
- **Resume / clear** — trash next to **Resume** clears watch progress and cached stream URLs for that title.

## Hub-specific play

| Hub | Default green Play | Notes |
|-----|-------------------|--------|
| **Anime** | Megaplay / VidNest / Miruro race (or Forja Auto when on) | AniList + MAL ids passed to providers; see [Anime](anime.md) tips for provider order |
| **Asian Drama** | KissKH native extract on enabled mirror | Upcoming titles disable play until published; mirror order under **Settings → Sources → Server reliability → Asian Drama** |

Loading uses the shared cinematic resolve overlay (**Finding / Checking / Probing / Opening**). **Cancel**, leaving the page, or switching tabs stops in-flight checks.

## Tips

- Enrich cache is session-scoped — reopening the same title reuses TMDB match without a second wait.
- **More Like This** rows that point at TMDB open [TMDB details](../movies-tv/tmdb-details.md).
- Playback, Sources panels in the player, and next-episode behavior match the main [Player](../playback/player.md) — hub titles use the same player shell as movies/TV.

## Related

- [Anime](anime.md) · [Asian Drama](asian-drama.md) — browse tabs
- [TMDB details](../movies-tv/tmdb-details.md)
- [Playback settings](../settings/playback-settings.md)
- [Next episode](../playback/next-episode.md)
