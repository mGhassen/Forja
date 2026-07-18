# 083 — Anime: stop at first playable stream (no background scan)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `AnimePlaybackBridge` · `AnimePlayerScreen` · player dead-source recovery

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix tasks · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I83-T01 | Anime race: `fillBackgroundHits: false` — stop after first playable extract | ✅ |
| 2 | I83-T02 | Loading → player: do not reset probe list (no fake full re-scan UI) | ✅ |
| 3 | I83-T03 | Anime Auto recovery also first-hit (no sibling background fill while playing) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I83-A01 | Play episode: loading stops when first CDN-probed stream is ready; remaining servers are not extracted in the background | ⬜ |
| 2 | I83-A02 | Opening the player does not restart provider chips from pending/trying for servers already decided | ⬜ |
| 3 | I83-A03 | Manual Source tap / dead-stream recovery still finds another server when needed | ⬜ |

---

## Summary

Anime Auto had been walking every provider (`fillBackgroundHits`) before open, then the player probe handoff reset chips so it looked like a second full scan. Policy now: **first playable wins** — open and stop. Other servers stay for explicit Source taps or dead-stream recovery only (also first-hit for anime).

## Related

- [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — earlier multi-hit fill (superseded for Auto play start)
- [Anime hub](../features/hubs/anime.md)
