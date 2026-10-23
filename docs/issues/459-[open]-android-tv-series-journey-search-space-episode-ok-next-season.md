# 459 — Android TV series journey: search space swallowed, episode OK dead, next episode ignores seasons, auto next missing, wrong-show subtitles

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · search field · details episodes · Exo player next episode · subtitles  
**Reported:** 2026-10-22 (remote-only walkthrough of a 9-season show on the Android TV emulator, profile build)

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** fix · **8 / 9** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Search → multi-season show → seasons → episode → play → subtitles → next episode → Back, all with the D-pad:

1. Typing in the search field drops every space: `rick and morty` becomes `rickandmorty`.
2. Episodes as number chips: OK selects a chip, a second OK does nothing. There is no way to play from the chip row.
3. Episodes as cards: OK arms the card and shows the play icon; a second OK does nothing. Only the hero Play button starts playback.
4. Next episode inside the player ignores seasons. The player receives every season as one flat list with per-season numbers, so "next" after S2E2 is resolved from the first season's E2 and the last episode of a season has no next (or targets an episode number that does not exist). The in-player Episodes panel lists 91 rows with repeating `E1…E11` badges and highlights the season-1 row.
5. The floating **Next episode** chip and the auto-next countdown never show on the pack play path; only the transport-bar button advances.
6. Subtitle menu: the first rows of English, French, Spanish… are subtitlecat files for another show (`Rick and Morty: The Anime S01E02`) and render nothing useful once picked.
7. Back out of the player after a next-episode switch: the details page reloads its progress too early (the awaited route was replaced by the next episode), and the search page behind it comes back empty because its state lived inside the subtree the player purge unmounts.

## Root cause (verified in code)

- Search: `host_search_wire.dart` `_searchFieldKeyEvent` swallowed every activate key (Select / Enter / **Space**) while editing to eat the OK twin that opened editing.
- Chips: the chip `onTap` only ever selected; no play path. Cards: the card's focus wrapper sets `descendantsAreFocusable: false` (`FocusableControl`, `allowNestedFocus` default), so the in-card play node never took focus and the second OK re-selected the card.
- Seasons: `PlayerKitEpisode` had no season; `episodesFromMeta` flattens `meta.videos`; `hubEpisodeIndex` matched by number only; `_hubEngineEpisodePicker` replayed the starting season; desktop / mobile mixins hard-coded `season: 1`; `advanceHubContinueAfterFinish` recorded the next number under the finished season.
- Chip / auto next: `nearEnd` and `_showNextEpChip` required `widget.onNextEpisode`, which the engine path never passes (it passes `episodes` + `onHubEpisodeSelected`).
- Subtitles: `crates/subtitles/src/subtitlecat.rs` `fetch_all` took the first search hits without checking the release name; the site matches substrings.
- Back: `_playEpisode` awaits `AppRouter.openPlayer`, which completes when the in-player switch replaces the route (`pushAndRemoveUntil`); `KitSearchScreen` wraps `KitSearchPage` in `PlayerSurfaceChromeStub`, so the page State (controller, query, results) is disposed on player enter.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I459-T01 | Search field: Space always reaches the field while editing; only the OK twin that opened editing is swallowed, Enter submits once typing is armed | ✅ |
| 2 | I459-T02 | Episode number chips: OK on the selected chip plays it (TV) | ✅ |
| 3 | I459-T03 | Episode cards: OK on the armed, selected card plays it (TV); no dependency on a nested play node | ✅ |
| 4 | I459-T04 | `PlayerKitEpisode.season`; hub index / adjacency season-aware with number-only fallback for flat lists; engine picker, desktop and mobile mixins, continue-watching advance use the picked row's season | ✅ |
| 5 | I459-T05 | In-player Episodes panel: current row matched by season + number; `S2 E3` badges when the list spans seasons | ✅ |
| 6 | I459-T06 | Next-episode chip, auto-next countdown and end-of-stream auto advance arm from the adjacency flags (host callback, hub list or TMDB), not only the host callback | ✅ |
| 7 | I459-T07 | subtitlecat: keep only releases named after the requested title (episode tag, year, region and quality tokens tolerated); unit tests | ✅ |
| 8 | I459-T08 | Details host waits for the player surface to close before reloading progress, so an in-player switch leaves the last watched episode selected | ✅ |
| 9 | I459-T09 | Search page keeps query, results, filters and focused card across a player session (session object owned by the screen outside the chrome stub) | ✅ |
| 10 | I459-T10 | Subtitle promo filter also drops the `hoofoot.ru` sports-stream ad cue injected at 0:00 by some French files | ✅ |
| 11 | I459-T11 | Review pass: end-of-stream auto advance only on a natural end (near-end window or seek bar at EOF); TMDB next claims `_loadingNextEp` before its lookup; episode video id looked up by season + number; subtitlecat matcher drops apostrophes, maps `&` to "and", parses `S1E2` tags numerically and ignores a `(US)` / `(2005)` title qualifier; search session restores a query with no results; details releases its surface wait on dispose | ✅ |
| 12 | I459-T12 | Residual flat-list next/prev and Episodes-panel fallback still forced `season: 1`; hub `markWatchedIfFinished` same — carry `selectedSeason` / episode season so S4E5 → S4E6 and details progress stays on S4 | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I459-A01 | Unit: season-aware index / next / flags (`next_aired_hub_episode_test.dart`) and subtitlecat release filter (`cargo test -p subtitles`) | ✅ |
| 2 | I459-A02 | TV emulator: typing `rick and morty` with spaces keeps the spaces | ✅ |
| 3 | I459-A03 | TV emulator: OK twice on an episode chip starts playback of that episode (chip 11 → S1E11); card path shares the rule, checked in code only | ✅ |
| 4 | I459-A04 | TV emulator: Next episode from S1E11 plays S2E1 (sources list `S02E01`); Episodes panel highlights the playing season row and shows `S2 E…` badges | ✅ |
| 5 | I459-A05 | TV emulator: at 21:25 / 22:51 the Next episode chip shows with its countdown and S2E2 starts on its own; Continue Watching seeded S2E2 | ✅ |
| 6 | I459-A06 | TV emulator: French list shows levrx and subtitlecat rows for the right show only; a French pick renders cues in the Flutter overlay | ✅ |
| 7 | I459-A07 | TV emulator: Back from the player after the auto advance shows the details page, Back again shows the `rick and morty` results with the opened card focused, Back again returns Home | ✅ |
| 8 | I459-A08 | Targeted app tests pass (`tv_season_episode_picker`, `player_next_episode_chip`, `exo_subtitle_session`, `catalog_hub_search_capabilities`, `engine_resume_progress`, `catalog_resume_seeds`, `shell_navigation_levels`) | ✅ |
| 9 | I459-A09 | Physical Android TV pass of A02–A07 | ⬜ |

## Residual (code fixed; A09 still open)

After T04, pack flat-list next/prev and the Episodes panel non-engine fallback still hard-coded season 1, and hub watched-mark used season 1 — so mid-season next (e.g. S4E5) jumped to S1E6 and details showed S1. Tracked as I459-T12. Keep issue **open** until I459-A09 physical pass.

## Also measured (not fixed here)

- Play → first frame on the profile emulator: 4.5 s cold open, 1.4 s on an in-player episode switch. Each open is followed by a TextureView remount + reopen (`[ExoPlayer] remount+reopen TextureView after …`), which replays the open once more; left as is because it guards issue 128 / 129 scaling on physical TVs.
- Picking an online subtitle rebuilds the media (sideload attach) and shows a few seconds of **Buffering**; a subtitlecat translated pick took 7–11 s to download through the local relay.
- Every in-player episode switch logs `remount+reopen TextureView after MediaKit surface race` although no MediaKit player was involved: the previous Exo teardown is tracked as a pending video dispose, so the next boot takes the MediaKit branch (350 ms cool-down + full stop/reopen after the first frame). On TV the reopen happens anyway (cold-open rule); on phone it turns a cheap remount into a reopen. Needs a dispose-kind flag in the exclusive session; not changed here (issue 128 / 129 territory).
- Fast-forward with the media key while chrome is visible drops roughly a third of the presses (each press is a separate seek that the previous seek has not finished).
- Details page for a 9-season show takes ~2.3 s (pack fetches every season at once; cached 1 h); the search request once took 21 s on the gateway.
- Season cards are built from `seasonCount` as `1..N`; a pack that lists a season 0 would mislabel the cards (issue noted, not changed).

## Links

- [RFC-122](../rfc/122-[draft]-android-tv-remote-ux.md) — Android TV remote pass this continues
- [458](fixed/458-[fixed]-exo-online-subtitle-pick-no-op-and-menu-twins.md) — subtitle pick path
- [120](120-[open]-android-tv-player-memory-purge.md) — chrome stub that unmounted the search page
- [314](314-[open]-details-episodes-chips-range-dpad.md) · [248](248-[open]-android-tv-player-episodes-search-dpad.md) — episode chips / panel D-pad neighbours
