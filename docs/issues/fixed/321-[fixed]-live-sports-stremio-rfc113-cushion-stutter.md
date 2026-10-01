# 321 — Live Sports player separated from IPTV (v1.5.36 MediaKit stack)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Stremio · MediaKit

**Related:** [RFC-113](../rfc/113-[open]-iptv-mediakit-direct-reconnect.md) · [295](fixed/295-[fixed]-mediakit-live-vt-hold-no-golive.md) · [273](fixed/273-[fixed]-iptv-hls-cold-open-watchdog-kill.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 8/8** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I321-T01 | Split MediaKit cold-open cushion: sports → v1.5.36 (`live/sports`); IPTV → `live/forja` | ✅ |
| 2 | I321-T02 | Restore sports-only ATV height tiers (`live_sports_atv_cache.dart`, back-bytes=0) | ✅ |
| 3 | I321-T03 | Leave IPTV RFC-113 `live/forja` props / recovery / lavf untouched | ✅ |
| 4 | I321-T04 | Sports watchdog: re-enable soft-reopen detectors (paint stall / buffering / self-pause) | ✅ |
| 5 | I321-T05 | Sports open: VLC UA + headers Media + v1.5.36 lavf string; skip HLS pin; no grace/goLive; VT hold | ✅ |
| 6 | I321-T06 | Sports tunables: UA / hls-bitrate / rtsp / hwdec pins / fflags without +igndts; ATV bufferSize 32 MiB | ✅ |
| 7 | I321-T07 | Extract `LiveSportsPlayerScreen` under `shared/player/live_sports/` (own library + route) | ✅ |
| 8 | I321-T08 | Strip all `_liveSportsSurface` / sportsMk branches from IPTV `pt_player_*`; route live opens to sports player | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I321-A01 | macOS Stremio Live Sports: route `live_sports_player`; log `profile=live/sports`; soft-reopen (not goLive); stable several minutes | ⬜ |
| 2 | I321-A02 | IPTV Xtream live: route `iptv_player`; log `profile=live/forja`; grace→goLive / no soft-reopen; no sports branches in IPTV player | ⬜ |

---

## Summary

Live Sports / Stremio inherited the IPTV RFC-113 MediaKit stack and stuttered. Flag forks inside `PtPlayerScreen` made the shared player a worse god file.

**Fix:** dedicated `LiveSportsPlayerScreen` (`apps/forja/lib/shared/player/live_sports/`) with the exact v1.5.36 MediaKit stack. `openForjaLiveNativePlayer` routes `BuiltInPlayerContext.live` / stremio / liveEngine there. IPTV `PtPlayerScreen` is RFC-113 only — no sports `if` branches.
