# Issue 153 — KissKh HLS: first frame then indefinite BUFFERING (4K ladder)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Asian Drama / KissKh playback (`shared/player/player/`, `kisskh`)

## Status at a glance

| | |
|--|--|
| **Progress** | **11 / 11** fix · **0 / 2** acceptance · **2 / 2** deferred |
| **Current slice** | Full KissKh playback policy reverted to pre-`df3992cd` (`pngStrip: never` / `openDirect`) — strip/cap/remount abandoned |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I153-T01 | Open KissKh HLS at a ≤1080p (or Settings max) media playlist instead of the master ABR URL | ✅ |
| 2 | I153-T02 | Keep quality-menu parse on the master URL when play already opened a capped variant | ✅ |
| 3 | I153-T03 | One-shot stall recovery: after confirm, if BUFFERING ≥18s with pos≈0, drop to lowest rung | ✅ |
| 4 | I153-T04 | KissKh `pngStrip: force` + mirror id resolve; strip post-IEND payload even without MPEG-TS sync (videotradercdn `.png`) | ✅ |
| 5 | I153-T05 | HLS proxy: protocol-relative `//cdn/…` must not join as `host//cdn/…`; collapse `hostA//hostB` joins | ✅ |
| 6 | I153-T06 | Cap KissKh catalog **before** OpenPipeline (strip keeps Referer); force strip never falls back to `openDirect` | ✅ |
| 7 | I153-T07 | `build_rust.sh` copies `libffi.dylib` into Debug/Release `.app` Frameworks (flutter run was on stale proxy) | ✅ |
| 8 | I153-T08 | Quality switch + stall drop remount through `resolveForcedPngStripPlayUrl` (never raw CDN) | ✅ |
| 9 | I153-T09 | Post-scrub BUFFERING ≥10s remounts strip at seek target (once) | ✅ |
| 10 | I153-T10 | Revert open ≤1080 cap + first-frame/seek stall remount watchdog (user regression — scrub worse) | ✅ |
| 11 | I153-T11 | Revert KissKh `pngStrip: force` (and force-only no-`openDirect`) — back to default `never` / `openDirect` like pre-`df3992cd` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I153-A01 | macOS: a title that previously stuck on BUFFERING after the splash frame advances past ~2s without hanging | ⬜ |
| 2 | I153-A02 | Logs show `[Player] KissKh HLS cap ≤…p → variant` (or stall drop) when the master has rungs above the cap | ⏭️ |
| 3 | I153-A03 | Logs show `[OpenPipeline] branch → openPngStrip` for KissKh `videotradercdn` / `.png` segment streams (not `mode=never` / `openDirect` only) | ⏭️ |
| 4 | I153-A04 | macOS: scrub / seek mid-episode continues (no indefinite BUFFERING) | ⬜ |

---

## Summary

**Symptom:** Asian Drama play resolves (`native resolve ok`) and opens, TextureGL gets a first frame, then playback / scrub sticks on **BUFFERING**. CDN segments are PNG-disguised (`videotradercdn` `.png`, protocol-relative `//cdn/…`).

**Attempted:** Force PNG-strip HLS proxy + ≤1080 cap + stall remounts. Strip opens (1280×640) but **scrub still BUFFERING**; cap/remount made scrub worse.

**Current (I153-T11):** KissKh playback profile removed — default `pngStrip: never` → OpenPipeline `openDirect` only (pre-`df3992cd` behavior). Proxy `//` join repair (T05/T07) kept for Megaplay / other strip users.

**Still open:** Reliable seek + start on PNG HLS without a scrub-breaking strip path — needs a new approach, not re-applying force strip.
