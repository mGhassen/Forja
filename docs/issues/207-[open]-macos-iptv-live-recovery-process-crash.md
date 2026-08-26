# 207 — macOS IPTV live: recovery thrash → process crash

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV live player · `iptv_live_continuity_proxy.dart` · `iptv_pt_player_engine.dart`  
**Reported:** 2026-08-26

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I207-T01 | Continuity proxy: never set `_closed=true` when mpv disconnects — only [stop] owns that flag (soft reopen race killed the new producer) | ✅ |
| 2 | I207-T02 | Live hard format/open fail always recovers (bypass false “working”); empty cache + no feed is not working | ✅ |
| 3 | I207-T03 | Cancel delayed live-edge `drop-buffers` on recovery/open/dispose; proxy empty reconnect no longer drop-buffers | ✅ |
| 4 | I207-T04 | Stop faking `_lastPosChange` on buffering-clear (made format fail look healthy) | ✅ |
| 5 | I207-T05 | MediaKit live: pulse playhead from `estimated-vf-fps` / `video-bitrate` — Stalker/TS with cache=0 no longer false underrun reopen every ~5s | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I207-A01 | macOS: flaky Xtream live channel that EOFs / “Failed to recognize file format” reconnects or shows offline banner — **no** `Lost connection to device` | ⬜ |
| 2 | I207-A02 | Healthy live channel still plays through CDN upstream EOF without reconnect thrash or process death | ⬜ |
| 3 | I207-A03 | macOS Stalker live: channel paints without `live underrun, cache empty` soft-reopen loop while picture is up | ⬜ |

---

## Summary

**Symptom:** Live IPTV plays, then CDN EOF / format fail / watchdog recovery ladder, then **process death** (`Lost connection to device`) right after `live-edge snap (force=true)` / reopen thrash.

**Root cause:**

1. Continuity proxy `_onRequest` `finally` set `_closed = true` when mpv closed the loopback socket. Soft reopen’s new `start()` generation was then killed by the old request’s finally → empty loopback → `Failed to recognize file format`.
2. Buffering-clear bumped `_lastPosChange`, so Stable treated dry demuxer + format fail as `skip recovery … working`.
3. Delayed `drop-buffers` (live-edge snap / proxy reconnect) raced `stop`+`open` on a dead demuxer → native crash (Dart `try/catch` cannot catch).

**Related:** [148](148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [199](199-[open]-android-tv-iptv-mediakit-silent-underrun-engine-swap.md) · [081](fixed/081-[fixed]-macos-quit-mpv-demux-sigsegv.md)
