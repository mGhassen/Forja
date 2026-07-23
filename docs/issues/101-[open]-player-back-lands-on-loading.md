# 101 — Player Back lands on stream loading screen

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** player exit · anime / Asian Drama / movie loading hosts

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I101-T01 | Register stream-loading routes (`loading_overlay`) for movie dialogs + anime/AD hosts | ✅ |
| 2 | I101-T02 | Player Back/Escape pops player then strips registered loading route in the same frame | ✅ |
| 3 | I101-T03 | Keep anime/AD host mounted during playback (I75 Source reload / handoff) — strip only on exit | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I101-A01 | Movie/TV: Back from player returns to details — not the resolve loading overlay | ⬜ |
| 2 | I101-A02 | Anime: Back from player returns to anime details — not `AnimePlayerScreen` loading | ⬜ |
| 3 | I101-A03 | Asian Drama: Back from player returns to drama details — not KissKh loading | ⬜ |

---

## Summary

Player and stream-loading UI share the **root** navigator. Details stay on the shell overlay. Back only popped `PlayerScreen`, so a loading dialog/host left underneath became visible — users saw the resolve roulette instead of details.

Movies/TV already strip the dialog via `crossfadeLoadingOverlayToPlayer` during the fade. Anime and Asian Drama **must** keep `AnimePlayerScreen` / `AsianDramaPlayerScreen` under the player for the whole session (issue [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — early `removeRoute` disposed Source cache / `onReloadStreams`). Those hosts are now registered and removed **on player exit only**, in the same frame as the player pop so the loading screen never paints.

## Related

- [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — why hub loading hosts stay under the player during playback
- [Player](../features/playback/player.md)
