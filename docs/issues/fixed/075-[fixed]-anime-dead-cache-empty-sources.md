# 075 — Anime dead session cache pins one stream / empty Sources

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/features/anime/anime_player_screen.dart`, player dead-cache recovery

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 12 / 12** fix · **4 / 6** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I75-T01 | Cache resume builds full embed/provider list before open (Sources not empty) | ✅ |
| 2 | I75-T02 | Session/disk cache resume does not set `pinSource` (blocks Auto recovery) | ✅ |
| 3 | I75-T03 | Dead cache uses `onReloadStreams` full embed race like movie Auto re-resolve | ✅ |
| 4 | I75-T04 | Drop anime session/disk cache when cache resume never confirms playback | ✅ |
| 5 | I75-T05 | Host reload path re-resolves even when Auto server is Off | ✅ |
| 6 | I75-T06 | Keep AnimePlayerScreen under player (do not removeRoute self — was disposing Source cache / onReloadStreams) | ✅ |
| 7 | I75-T07 | Anime domain host race fills sibling provider hits (`fillBackgroundHits`) | ✅ |
| 8 | I75-T08 | Probe CDN URLs before launch / cache write; skip dead preferred and fall through to Auto | ✅ |
| 9 | I75-T09 | Dead-cache recovery races anime providers without `cancelAllPending` first; clears temporary pins | ✅ |
| 10 | I75-T10 | Do not overwrite preferred source on abortive open; ignore cache that misses preferred key | ✅ |
| 11 | I75-T11 | Anime resume ≥90% restarts at 0 (same rule as movies) | ✅ |
| 12 | I75-T12 | Resolve/switch/cache keys use `hubEpisodeNumber ?? selectedEpisode` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I75-A01 | Cache replay with dead CDN: Source panel lists all servers / full re-resolve | ✅ |
| 2 | I75-A02 | Feature doc: anime dead-cache recovery matches movies | ✅ |
| 3 | I75-A03 | Manual: replay ep after CDN expires → recovers or shows full Source list | ⬜ |
| 4 | I75-A04 | Manual: tap unloaded anime servers in Source while playing → checking spinner / streams | ⬜ |
| 5 | I75-A05 | Feature doc + changelog: multi-server race, probe-before-open, ≥90% resume restart | ✅ |
| 6 | I75-A06 | Manual: preferred kiwi with bee-only dead cache → full Auto finds another server | ⬜ |

---

## Summary

Anime episode replay hit a 1-URL session/disk cache, launched with `pinSource: true`, and never built `_allEmbeds` — so Sources showed only the failed HLS row. The player dropped `WebstreamingStreamCache` (`anime:-id`) but left the anime stream cache intact, and `Playback failed — no auto failover (pinned)` stopped recovery.

A follow-on failure: `AnimePlayerScreen` called `navigator.removeRoute(ModalRoute.of(context))` on fade / playback-start — that **is** the anime loading route itself. Disposing it mid-session killed `providerSourcesCache` / probes and made `onReloadStreams` return null (`_cancelled` after dispose), so dead-cache Auto re-resolve and Source server taps did nothing. Asian Drama had the same early-remove pattern.

Root chain (later slice): anime host race returned only the first extract winner (often `miruro:bee`), so the playlist was `1/1`; dead-cache “full Auto” called `cancelAllPending()` (cold Miruro) then reloaded empty/same dead URLs; settings Auto Off kept same-panel re-extract; preferred kiwi was overwritten by an abortive bee open; ≥90% resume sought into credits.

Movie [043](043-[fixed]-dead-cache-full-auto-reresolve.md) already drops cache and re-resolves like green Play. Anime now fills multi-provider hits, probes before open, recovers without false pin / cancel-before-Miruro, and keeps the host route alive under the player until the player pops.

## Related

- [043](043-[fixed]-dead-cache-full-auto-reresolve.md) — movie/webstreaming dead-cache Auto re-resolve
- [Anime](../features/hubs/anime.md)
