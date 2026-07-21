# 090 — Details Resume / progress bar missing (desktop watch history)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** watch history · media details · Continue Watching · desktop player

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** fix · **2/3** acceptance (manual smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I90-T01 | Preserve selected episode when `_fetchSeason` reloads the same season (history resolve) | ✅ |
| 2 | I90-T02 | Details refreshes `_lastProgress` from `WatchHistoryService.historyStream` | ✅ |
| 3 | I90-T03 | Desktop player: 15s progress persist + await `saveProgress` before latching exit flag | ✅ |
| 4 | I90-T04 | Coerce watch-history JSON numbers via `watchHistoryInt` (Resume / CW / hero) | ✅ |
| 5 | I90-T05 | Hero meta budget no longer drops the progress bar before other chrome | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I90-A01 | Unit: `watchHistoryInt` + resume position with double JSON values | ✅ |
| 2 | I90-A02 | TV details: reopen in-progress episode → Resume + bar for that S/E | ⬜ |
| 3 | I90-A03 | Movie details: watch mid-title, exit, stay on details → Resume + bar without leaving | ⬜ |

---

## Summary

Details showed Play (not Resume) and no progress bar for movies and TV even after reopening. Continue Watching was flaky.

### Root causes

1. **TV:** `_resolveInitialSeasonEpisode` set the in-progress S/E, then `_fetchSeason` forced episode **1**, so `_checkHistory` looked up the wrong uniqueId.
2. **Stale UI:** details never re-read history after the player saved (no stream subscription).
3. **Save reliability:** desktop only saved on lifecycle/exit; `_historySaved` latched before a durable write; no periodic persist.
4. **JSON casts:** `as int` on progress fields / CW cards could throw when values came back as `num`.

### Fix (shipped)

- Keep prior episode when refetching the same season; only reset to E1 on season change.
- Subscribe details to `historyStream` and refresh hero + episode rails.
- Desktop 15s timer + await `WatchHistoryService.saveProgress`; exit still writes the latest position.
- Shared `watchHistoryInt` for reads; keep progress bar in the hero budget.

## Related

- [072](fixed/072-[fixed]-torrent-early-eof-false-completed-autonext.md) — early-EOF skip + 2–90% resume rule
- [Watch history](../../features/movies-tv/watch-history.md)
