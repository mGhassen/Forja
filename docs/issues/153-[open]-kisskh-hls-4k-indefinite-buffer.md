# Issue 153 — KissKh HLS: first frame then indefinite BUFFERING (4K ladder)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Asian Drama / KissKh playback (`shared/player/player/`, `kisskh`)

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 3** acceptance · **1 / 1** deferred (A02 cap logs) |
| **Current slice** | Cap + stall remount **reverted** (I153-T10) — PNG strip force remains; scrub still open |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I153-A01 | macOS: a title that previously stuck on BUFFERING after the splash frame advances past ~2s without hanging | ⬜ |
| 2 | I153-A02 | Logs show `[Player] KissKh HLS cap ≤…p → variant` (or stall drop) when the master has rungs above the cap | ⏭️ |
| 3 | I153-A03 | Logs show `[OpenPipeline] branch → openPngStrip` for KissKh `videotradercdn` / `.png` segment streams (not `mode=never` / `openDirect` only) | ⬜ |
| 4 | I153-A04 | macOS: scrub / seek mid-episode continues (no indefinite BUFFERING); logs must not show `priorFail→openDirect` for KissKh | ⬜ |

---

## Summary

**Symptom:** Asian Drama play resolves (`native resolve ok`) and opens (`openDirect`), TextureGL gets a first frame (often a title splash at 3840×2160), then ABR ladders while the player UI stays on **BUFFERING / 0 / 1**. mpv floods `obu_forbidden_bit` / `Failed to parse temporal unit` while fetching `…/2160/*.png` from `videotradercdn`.

**Root (corrected):** KissKh CDN segments are **PNG-disguised media**. Provider profile defaulted to `pngStrip: never`, so RFC-045 stayed on `openDirect` and ffmpeg tried to demux PNG shells as AV1/HLS — intermittent yuv frames then infinite buffer. Soft `hls-bitrate` / 1080p variant pick alone does not unwrap PNG.

**Shipped (kept):** Force `/hls-proxy?strip=png` with **no** `openDirect` fallback; unwrap post-IEND bytes; repair protocol-relative / double-authority CDN joins; Debug `.app` dylib copy.

**Reverted (I153-T10):** ≤1080 open-cap, first-frame quality drop, and post-scrub strip remount. Live macOS: openPngStrip + seek remount still left scrub BUFFERING (`KissKh seek stall 10s → remount strip` then hang). Cap/remount made scrub worse than pre-`df3992cd`.
