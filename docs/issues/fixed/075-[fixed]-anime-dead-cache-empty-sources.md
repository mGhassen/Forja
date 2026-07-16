# 075 — Anime dead session cache pins one stream / empty Sources

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/features/anime/anime_player_screen.dart`, player dead-cache recovery

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **2 / 3** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I75-A01 | Cache replay with dead CDN: Source panel lists all servers / full re-resolve | ✅ |
| 2 | I75-A02 | Feature doc: anime dead-cache recovery matches movies | ✅ |
| 3 | I75-A03 | Manual: replay ep after CDN expires → recovers or shows full Source list | ⬜ |

---

## Summary

Anime episode replay hit a 1-URL session/disk cache, launched with `pinSource: true`, and never built `_allEmbeds` — so Sources showed only the failed HLS row. The player dropped `WebstreamingStreamCache` (`anime:-id`) but left the anime stream cache intact, and `Playback failed — no auto failover (pinned)` stopped recovery.

Movie [043](043-[fixed]-dead-cache-full-auto-reresolve.md) already drops cache and re-resolves like green Play. Anime now follows that: seed the full server list on cache resume, do not pin from session cache, reload via the anime embed race on dead sources, and drop the anime stream cache when a cache resume never confirms playback.

## Related

- [043](043-[fixed]-dead-cache-full-auto-reresolve.md) — movie/webstreaming dead-cache Auto re-resolve
- [Anime](../features/hubs/anime.md)
