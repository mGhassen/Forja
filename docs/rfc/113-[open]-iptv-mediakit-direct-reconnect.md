# RFC-113: IPTV MediaKit — direct CDN + lavf reconnect

**Status:** open  
**Depends on:** —  
**Area:** `apps/forja/lib/shared/player/live/`

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 13** components · **2 / 10** acceptance (manual QA) |
| **Current slice** | Full Forja MediaKit live: decode/controller + lavf + grace/goLive |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R113-C01 | Delete `LiveContinuityProxy` / overlap skip; MediaKit live opens CDN direct | ✅ |
| 2 | R113-C02 | Live mpv props (`stream-lavf-o`, cache, demuxer 128+64, ATV `cache-on-disk=no`) | ✅ |
| 3 | R113-C03 | Live recovery: silent grace → `goLive` stop+open (ATV grace/attempt forks) | ✅ |
| 4 | R113-C04 | Buffering chrome from engine stream only; clear latch when stream working | ✅ |
| 5 | R113-C05 | Android video path verified (Impeller OpenGLES ATV; no Skia force regress) | ✅ |
| 6 | R113-C06 | Changelog + IPTV feature docs; no localhost-relay language | ✅ |
| 7 | R113-C07 | ATV Impeller off (Skia) — `EnableImpeller=false` | ✅ |
| 8 | R113-C08 | HLS MediaKit: `reconnect=0` (playlist EOF; issue 273) — progressive keeps lavf reconnect | ✅ |
| 9 | R113-C09 | MediaKit live: no watchdog soft-reopen underrun (grace → goLive only) | ✅ |
| 10 | R113-C10 | Android Impeller off globally (`EnableImpeller=false` manifest) | ✅ |
| 11 | R113-C11 | MediaKit live: default `VideoController` (non-ATV); never TextureSW (incl. Windows); no extra live mpv pins | ✅ |
| 12 | R113-C12 | Live `demuxer-lavf-o` `+igndts` (DAI pts&lt;dts) — Forja live path; restores issue 273 | ✅ |
| 13 | R113-C13 | Live lavf: always `reconnect=1…delay_max=5` (ipdigi) — supersedes C08 HLS `reconnect=0` ([357](../../issues/357-[open]-iptv-vod-mediakit-ipdigi-parity.md)) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R113-A01 | Desktop MediaKit Xtream TS: `direct open`, zero `[IPTV Proxy]`, ≥10 min | ⬜ |
| 2 | R113-A02 | Panel EOF: silent grace recovers without soft-reopen storm / replay loop | ⬜ |
| 3 | R113-A03 | Grace fail → goLive reopen then ok or ended — not 1Hz skip-recovery spam | ⬜ |
| 4 | R113-A04 | ATV MediaKit: Forja live demuxer bytes; cache-on-disk=no; grace 9s / max 1 goLive | ⬜ |
| 5 | R113-A05 | HLS MediaKit still `reconnect=0` (Forja issue 273) | ✅ |
| 6 | R113-A06 | Exo IPTV live unchanged (direct CDN) | ⬜ |
| 7 | R113-A07 | Progressive MediaKit uses lavf reconnect; HLS keeps `reconnect=0` | ✅ |
| 8 | R113-A08 | Android Impeller off globally (manifest); MediaKit video paints phone+TV | ⬜ |
| 9 | R113-A09 | MediaKit live underrun does not soft-reopen via watchdog — grace/goLive only | ⬜ |
| 10 | R113-A10 | Live lavf string matches ipdigi on HLS + progressive (`reconnect=1…delay_max=5`) — [357](../../issues/357-[open]-iptv-vod-mediakit-ipdigi-parity.md) A03 | ⬜ |

---

## Summary

Replace Forja’s MediaKit Xtream/M3U **continuity proxy** with CDN-direct live playback:

1. Open CDN URL in mpv (keep panel headers if needed).
2. ffmpeg `stream-lavf-o` reconnect (`reconnect_delay_max=5`) for **all** live MediaKit URLs (progressive + HLS) — ipdigi parity ([357](../../issues/357-[open]-iptv-vod-mediakit-ipdigi-parity.md) T04; C08 HLS `reconnect=0` superseded).
3. Page-level silent grace (6s / ATV 9s) then `stop`+`open` (`goLive`) — **no** MediaKit live soft-reopen underrun.
4. Android: Impeller **off** globally (manifest); TV also forces SurfaceTexture producers.

### Related

- Issue 273 — HLS cold-open hold / `+igndts` / ABR pin remain; T05 `reconnect=0` superseded by R113-C13 / issue 357 T04
- Issue 357 — VOD + live lavf ipdigi parity
- Issue 155 — ATV OOM risk with fat demuxer; soak A04
- Issue 215 — glyph risk on leanback Skia; soak A08
- RFC-107 — Exo/AVPlayer/VLC stay; MediaKit live path changes here
