# RFC-113: IPTV MediaKit — ipdigi direct CDN + lavf reconnect

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja/lib/shared/player/live/`

## Status at a glance

| | |
|--|--|
| **Progress** | **9 / 9** components · **0 / 9** acceptance (manual QA) |
| **Current slice** | Full ipdigi parity: lavf HLS + ATV Skia + no MK live soft-reopen |

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
| 7 | R113-C07 | ATV Impeller off (Skia) — match ipdigi `EnableImpeller=false` | ✅ |
| 8 | R113-C08 | HLS MediaKit uses same lavf reconnect string as progressive (ipdigi) | ✅ |
| 9 | R113-C09 | MediaKit live: no watchdog soft-reopen underrun (grace → goLive only) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R113-A01 | Desktop MediaKit Xtream TS: `direct open`, zero `[IPTV Proxy]`, ≥10 min | ⬜ |
| 2 | R113-A02 | Panel EOF: silent grace recovers without soft-reopen storm / replay loop | ⬜ |
| 3 | R113-A03 | Grace fail → goLive reopen then ok or ended — not 1Hz skip-recovery spam | ⬜ |
| 4 | R113-A04 | ATV MediaKit: ipdigi demuxer bytes; cache-on-disk=no; grace 9s / max 1 goLive | ⬜ |
| 5 | R113-A05 | HLS MediaKit still `reconnect=0` (Forja issue 273) | ⏭️ |
| 6 | R113-A06 | Exo IPTV live unchanged (direct CDN) | ⬜ |
| 7 | R113-A07 | HLS MediaKit uses ipdigi lavf reconnect (no Forja `reconnect=0` fork) | ⬜ |
| 8 | R113-A08 | ATV boots Impeller off (Skia); MediaKit video paints; soak glyphs | ⬜ |
| 9 | R113-A09 | MediaKit live underrun does not soft-reopen via watchdog — grace/goLive only | ⬜ |

---

## Summary

Replace Forja’s MediaKit Xtream/M3U **continuity proxy** with the verified [ipdigi-oss](https://github.com/atillayurtseven/ipdigi-oss) live model:

1. Open CDN URL in mpv (keep panel headers if needed).
2. ffmpeg `stream-lavf-o` reconnect (`reconnect_delay_max=5`) for progressive **and** HLS.
3. Page-level silent grace (6s / ATV 9s) then `stop`+`open` (`goLive`) — **no** MediaKit live soft-reopen underrun.
4. Android TV: Impeller **off** (Skia), same as ipdigi; phones keep Flutter default Impeller.

**Reference:** `ipdigi-oss` `player_controller.dart` + `player_page.dart` live recovery.

### Related

- Issue 273 — superseded for live by R113-A07 (ipdigi HLS reconnect); watch A07 soak
- Issue 155 — ATV OOM risk with fat demuxer; soak A04
- Issue 215 — glyph risk on leanback Skia; soak A08
- RFC-107 — Exo/AVPlayer/VLC stay; MediaKit live path changes here
