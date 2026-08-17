# 181 — In-player source switch aborted by stale playback error

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** player · Android TV · Sources / Source / Quality · MediaKit · ExoPlayer

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I181-T01 | Webstreaming `_switchToStreamSource` (mobile + desktop): fence with `_isInitPlaybackRunning`; clear checking on abort | ✅ |
| 2 | I181-T02 | Catalog HTTP `_switchStremioSource` (mobile + desktop MediaKit): same init fence + clear error before stop | ✅ |
| 3 | I181-T03 | Magnet / torrent in-player switch: supersede `_isLoadingNextEp` instead of silent return after panel dismiss | ✅ |
| 4 | I181-T04 | Exo catalog / stream switch: keep `_opening` true so native error does not failover mid-switch | ✅ |
| 5 | I181-T05 | HLS `_switchQuality`: fence open; Sources `_isCurrentStremio` must not treat different HTTP URL as current via infoHash | ✅ |
| 6 | I181-T06 | Same-server quality rows: only no-op when selected index is already the playing row | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I181-A01 | Videasy (or any webstreaming): play one quality → pick another in Source → new stream opens (not stuck Checking / black) | ⬜ |
| 2 | I181-A02 | Android TV: failed Nuvio/Stremio HTTP → Sources → another stream → opens or shows fail, never silent no-op | ⬜ |
| 3 | I181-A03 | Failed torrent/magnet → Sources → another magnet → loading card + resolve (not dismiss-then-nothing) | ⬜ |
| 4 | I181-A04 | HLS Quality chip switch continues playback on the locked variant | ⬜ |

---

## Summary

After a failed or mid-play stream, picking another source in the player (webstreaming Source panel, catalog Sources, or Quality) often did nothing or left the player black/stuck on Checking.

**Root cause:** MediaKit in-player switches bump `_fallbackGen` and call `stop()` / reopen **without** setting `_isInitPlaybackRunning`. The error listener treats the stop as a mid-watch failure, bumps `_fallbackGen` again, and the switch aborts on `_fallbackAborted`. Magnet switches dismiss the Sources panel then hit `if (_isLoadingNextEp) return` during a prior fail card. Catalog “current” matching can treat a different HTTP URL as current via shared `infoHash`. Exo native `error` during switch can failover while a manual switch is in flight.

**Fix shipped:** all in-player switch paths fence stop/open like `_initPlayback` (MediaKit `_isInitPlaybackRunning`, Exo `_opening`); magnet picks supersede the loading card; quality rows switch by index; remote HTTP Sources identity is play-URL only.
