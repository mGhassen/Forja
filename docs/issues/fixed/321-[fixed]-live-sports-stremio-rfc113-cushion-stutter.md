# 321 — Live Sports Stremio must match v1.5.36 MediaKit stack

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Stremio · MediaKit

**Related:** [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) · [295](fixed/295-[fixed]-mediakit-live-vt-hold-no-golive.md) · [273](fixed/273-[fixed]-iptv-hls-cold-open-watchdog-kill.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6/6** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I321-T01 | Split MediaKit cold-open cushion: sports → v1.5.36 (`live/sports`); IPTV → `live/forja` | ✅ |
| 2 | I321-T02 | Restore sports-only ATV height tiers (`live_sports_atv_cache.dart`, back-bytes=0) | ✅ |
| 3 | I321-T03 | Leave IPTV RFC-113 `live/forja` props / recovery / lavf untouched | ✅ |
| 4 | I321-T04 | Sports watchdog: re-enable soft-reopen detectors (paint stall / buffering / self-pause); IPTV keeps grace→goLive early-return | ✅ |
| 5 | I321-T05 | Sports open: VLC UA + headers Media + v1.5.36 lavf string; skip HLS pin; no grace/goLive; VT hold; jump-to-live | ✅ |
| 6 | I321-T06 | Sports tunables: UA / hls-bitrate / rtsp / hwdec pins / fflags without +igndts; ATV bufferSize 32 MiB | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I321-A01 | macOS Stremio Live Sports: log `profile=live/sports`; soft-reopen (not goLive) on underrun; stream stable several minutes | ⬜ |
| 2 | I321-A02 | IPTV Xtream live still logs `profile=live/forja` with grace→goLive / no soft-reopen | ⬜ |

---

## Summary

After RFC-113, Live Sports / Stremio inherited the IPTV IPDigi MediaKit stack (fat cushion, grace→goLive, no soft-reopen, no UA, HLS `reconnect=0`). Users saw stutter vs the last released sports path.

**Fix:** gate every sports-facing MediaKit behavior on `_liveSportsSurface` (`BuiltInPlayerContext.live`) and restore the **exact v1.5.36** sports system: cushion, watchdog soft-reopen, headers open, lavf `delay_max=30`, VT hold, jump-to-live, UA/hwdec/fflags. IPTV stays on RFC-113.
