# 083 — Anime: stop at first playable stream (no background scan)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `AnimePlaybackBridge` · `AnimePlayerScreen` · player dead-source recovery

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I83-T01 | Anime race: stop after first **CDN-playable** stream (not first extract) | ✅ |
| 2 | I83-T02 | Loading → player: do not reset probe list (no fake full re-scan UI) | ✅ |
| 3 | I83-T03 | Anime Auto recovery also first-hit (no sibling background fill while playing) | ✅ |
| 4 | I83-T04 | Dead CDN on first extract: skip that server and try next (do not burn “Search again”) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I83-A01 | Play episode: loading stops when first CDN-probed stream is ready; remaining servers are not extracted in the background | ⬜ |
| 2 | I83-A02 | Opening the player does not restart provider chips from pending/trying for servers already decided | ⬜ |
| 3 | I83-A03 | Manual Source tap / dead-stream recovery still finds another server when needed | ⬜ |

---

## Summary

Anime Auto had been walking every provider (`fillBackgroundHits`) before open, then the player probe handoff reset chips so it looked like a second full scan. Policy now: **first CDN-playable wins** — try servers in order, probe each extract, open on the first that works, then stop. A dead CDN on an early extract no longer stops the whole search or dumps you on “Search again” after one miss. Other servers stay for explicit Source taps or dead-stream recovery.

## Related

- [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — earlier multi-hit fill (superseded for Auto play start)
- [Anime hub](../features/hubs/anime.md)
