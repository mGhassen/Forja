# RFC-113: IPTV MediaKit — ipdigi direct CDN + lavf reconnect

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja/lib/shared/player/live/`

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **0 / 6** acceptance (manual QA) |
| **Current slice** | Deltas closed vs ipdigi (cache-on-disk, grace/goLive, buffering chrome) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R113-C01 | Delete `LiveContinuityProxy` / overlap skip; MediaKit live opens CDN direct | ✅ |
| 2 | R113-C02 | Live mpv props match ipdigi (`stream-lavf-o`, cache, demuxer 128+64, ATV `cache-on-disk=no`) | ✅ |
| 3 | R113-C03 | Live recovery: silent grace → `goLive` stop+open (ATV grace/attempt forks) | ✅ |
| 4 | R113-C04 | Buffering chrome from engine stream only; clear latch when stream working | ✅ |
| 5 | R113-C05 | Android video path verified (Impeller OpenGLES ATV; no Skia force regress) | ✅ |
| 6 | R113-C06 | Changelog + IPTV feature docs; no localhost-relay language | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R113-A01 | Desktop MediaKit Xtream TS: `direct open`, zero `[IPTV Proxy]`, ≥10 min | ⬜ |
| 2 | R113-A02 | Panel EOF: silent grace recovers without soft-reopen storm / replay loop | ⬜ |
| 3 | R113-A03 | Grace fail → goLive reopen then ok or ended — not 1Hz skip-recovery spam | ⬜ |
| 4 | R113-A04 | ATV MediaKit: ipdigi demuxer bytes; cache-on-disk=no; grace 9s / max 1 goLive | ⬜ |
| 5 | R113-A05 | HLS MediaKit still `reconnect=0` (Forja issue 273) | ⬜ |
| 6 | R113-A06 | Exo IPTV live unchanged (direct CDN) | ⬜ |

---

## Summary

Replace Forja’s MediaKit Xtream/M3U **continuity proxy** with the verified [ipdigi-oss](https://github.com/atillayurtseven/ipdigi-oss) live model:

1. Open CDN URL in mpv (keep panel headers if needed).
2. ffmpeg `stream-lavf-o` reconnect (`reconnect_delay_max=5`).
3. Page-level silent grace (6s / ATV 9s) then `stop`+`open` (`goLive`), not a Dart loopback proxy.

**Android Impeller:** Forja does **not** copy ipdigi’s manifest `EnableImpeller=false`. Leanback uses **Impeller + OpenGLES** + `vo=mediacodec_embed` + SurfaceTexture producers (`TvFlutterShellArgs` / `ForjaApplication`) — Skia-off Impeller corrupted glyphs on physical ATV.

**Reference:** `ipdigi-oss` `player_controller.dart` + `player_page.dart` live recovery.

### Related

- Issue 272 / 273 — HLS must not use lavf reconnect-on-EOF
- Issue 155 — ATV OOM risk with fat demuxer; soak A04
- RFC-107 — Exo/AVPlayer/VLC stay; MediaKit progressive path changes here
