# 062 — Windows quit freezes (unbounded mpv teardown)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `bootstrap.dart` · `MpvExclusiveSession` · desktop `onWindowClose`  
**Reported:** 2026-07-15  
**Fixed:** 2026-07-15

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance (manual Windows smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I62-T01 | `shutdownAllPlayers` uses timed `teardownMediaKitPlayer` (no unbounded stop/dispose) | ✅ |
| 2 | I62-T02 | Music / audiobook `releaseMpvForVideo` uses timed teardown | ✅ |
| 3 | I62-T03 | `onWindowClose`: hide window immediately; timeout media_kit + engine shutdown | ✅ |
| 4 | I62-T04 | Do not await sync torrent `torrentEngineStop` on quit (blocks isolate; timeouts cannot fire) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I62-A01 | Windows release: close while idle / after playback / with Anime loading — window hides and process exits without multi-second freeze | ⬜ |

---

## Summary

**1.2.192 Windows** still froze on exit after [061](061-[fixed]-engine-worker-hang-on-quit.md) (engine worker / AniList shutdown). That fix was real but incomplete for Windows close.

**Root cause:** Desktop `onWindowClose` keeps `setPreventClose(true)` and **awaits** `_shutdownMediaKitPlayers()` → `shutdownAllPlayers()`, which called unbounded `player.stop()` / `player.dispose()` and waited forever on `_pendingVideoDispose`. media_kit can hang on video-controller init ([059](059-[fixed]-vod-player-audio-continues-after-exit.md)). Sync `torrentEngineStop` (`block_on`) on the same isolate also cannot be interrupted by `Future.timeout`.

**Fix:** Timed mpv teardown (same helpers as 059), hide the window immediately, timeout engine shutdown, skip awaiting torrent/proxy/cache on the quit path so destroy always runs.

## Verify

1. Windows build with this change
2. Quit from Home (idle), after watching a stream, and while Anime is loading
3. Window should disappear promptly; process should exit

## Related

- [061](061-[fixed]-engine-worker-hang-on-quit.md) — engine worker isolate hang (separate; still required)
- [059](059-[fixed]-vod-player-audio-continues-after-exit.md) — timed `teardownMediaKitPlayer`
