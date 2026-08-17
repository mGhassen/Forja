# 186 — Paused playback still heartbeats watch history and Simkl/Trakt

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** `apps/forja/lib/shared/player/player/` (desktop, mobile, Exo)

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I186-T01 | Desktop: 15s history heartbeat only while playing; persist once on pause; scrobble stop only on exit / episode switch | ✅ |
| 2 | I186-T02 | Mobile: same persist/scrobble split (pause persist + stop on exit; no tracker on lifecycle heartbeat) | ✅ |
| 3 | I186-T03 | Exo: 15s `onSaveProgress` only while playing; start/pause/stop scrobble on play/pause/exit | ✅ |
| 4 | I186-T04 | Changelog + player / watch-history / Simkl / Trakt feature docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I186-A01 | Manual: pause a movie — no 15s `[WatchHistory]` / `[Simkl] Scrobble` while paused; resume still starts; leave still stops and saves | ⬜ |

---

## Summary

The desktop (and Exo) 15s persist timer did not look at play/pause. `_saveWatchHistory(isBgPause: true)` rewrote local watch history and sent Trakt `pause` + Simkl `stop` every tick, including while paused (and while playing). Pause already had a one-shot `scrobblePause` from the playing listener.

Root: local crash-safety heartbeat piggybacked tracker scrobbles. Heartbeat is local-only and playing-only; pause persists once; Simkl/Trakt only on start / pause / stop / exit.

## Related

- [Watch history](../features/movies-tv/watch-history.md)
- [Simkl](../features/accounts/simkl.md)
- [Trakt](../features/accounts/trakt.md)
- [Player](../features/playback/player.md)
