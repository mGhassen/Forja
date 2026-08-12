# RFC-059: Anime & Asian Drama list follow

**Status:** fixed  
**Depends on:** —  
**Area:** Anime / Asian Drama / My List / Simkl  
**Version:** v1.4 Atarin

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Details `+`, Play → Watching, Simkl write, scrobble guard |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R59-C01 | Local My List rows for AniList + KissKH (`anilist_*` / `kisskh_*`) | ✅ |
| 2 | R59-C02 | Simkl write: anime via `ids.anilist`; drama via TMDB show/movie when matched | ✅ |
| 3 | R59-C03 | Details `+` status pin + Play → Watching | ✅ |
| 4 | R59-C04 | Skip TMDB scrobble for hub `mediaType` / negative ids; episode history on finish | ✅ |

---

## Acceptance (hub follow)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R59-A01 | Anime details `+` sets Plan to Watch / Watching / On Hold / Completed / Dropped locally | ✅ |
| 2 | R59-A02 | Anime `+` / Play writes Simkl `anime` with AniList id when connected | ✅ |
| 3 | R59-A03 | Playing anime (empty or Plan to Watch) moves it to Watching | ✅ |
| 4 | R59-A04 | Asian Drama details `+` is the same local statuses (KissKH id) | ✅ |
| 5 | R59-A05 | Drama with TMDB match syncs as TV/movie to Simkl (Trakt if admin) | ✅ |
| 6 | R59-A06 | Drama with no TMDB match stays local and still appears on My List | ✅ |
| 7 | R59-A07 | Hub players do not scrobble negative KissKH/AniList ids as TMDB | ✅ |
| 8 | R59-A08 | Feature docs + changelog | ✅ |

---

## Summary

Anime and Asian Drama details have Play (and SUB/DUB) but no list pin. Playback scrobbles fake TMDB ids (`-anilistId` / `-kisskhId`). Users cannot follow a show while watching.

## Goals

1. Same details `+` as movies/TV.
2. Simkl is the user-facing tracker (Trakt admin-only, TMDB titles only).
3. Local list always writes. Tracker writes when ids exist.
4. Stop garbage TMDB scrobbles.

## Contracts

- Anime key: `anilist_{id}`. Simkl body: `{ "anime": [{ "ids": { "anilist": N }, "to": "…" }] }`.
- Drama key: `kisskh_{id}`. Simkl/Trakt only when a confident TMDB match exists (`movie` or `tv`).
- Play auto-status: empty or `plantowatch` → `watching`. Do not clobber hold / dropped / completed.
- Episode ≥85% → Simkl history (anime episode number; drama season 1 + TMDB episode when matched).
- My List Anime filter includes local AniList rows. Drama rows use the TV Shows filter.
- Unmatched drama rows merge into My List even while Simkl is connected.

## Related

- [My List](../features/movies-tv/my-list.md)
- [Simkl](../features/accounts/simkl.md)
- [Anime](../features/hubs/anime.md)
- [Asian Drama](../features/hubs/asian-drama.md)
- [RFC-053](053-[partial]-asian-drama-tmdb-details.md) — TMDB match reused for drama tracker ids
