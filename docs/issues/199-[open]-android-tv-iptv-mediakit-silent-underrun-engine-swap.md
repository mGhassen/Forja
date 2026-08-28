# 199 — Android TV IPTV MediaKit: silent underrun + Reload auto-swaps engine

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV live player (Android TV, MediaKit) · `iptv_pt_player_engine*.dart` · `iptv_pt_player_screen.dart`  
**Reported:** 2026-08-23

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 13** fix · **0 / 7** acceptance |
| **Current slice** | ATV perf + engine part split shipped — device smoke outstanding |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I199-T01 | Live MediaKit: `cache-pause=yes` + `cache-pause-initial=yes` (continuity proxy absorbs CDN closes — revisit [I148-T20](148-[open]-iptv-live-edge-snap-reconnect-loop.md)) so underrun pauses and refills instead of freezing silently | ✅ |
| 2 | I199-T02 | Live never auto-swaps MediaKit↔Exo on unrecognized-format / hard-open errors (Reload / empty reopen) — Player menu only; guard call sites + `_autoSwapEngineForFormatError` | ✅ |
| 3 | I199-T03 | Feed / proxy ticks must not fake playhead or hide **Buffering…** when demuxer cache is empty (`_videoAdvancing`, `_playheadRecentlyMoved`, `_noteFeedProgress`, `_streamWorking`) | ✅ |
| 4 | I199-T04 | Watchdog: MediaKit live underrun while still “playing” shows Buffering and soft-reopens; self-pause hold no longer treats feed-only as healthy | ✅ |
| 5 | I199-T05 | Revert live `cache-pause=no` + `demuxer-max-back-bytes=0` — T01 pause-refill caused clockwork ~5–6s micro-freezes on every CDN proxy reopen (3MiB overlap skip); keep T02–T04 | ✅ |
| 6 | I199-T06 | Stop equating healthy demuxer cache + feed with painting (`_playheadRecentlyMoved`, `_videoAdvancing`, `_noteFeedProgress`) — VO can freeze with ~30s cache | ✅ |
| 7 | I199-T07 | Paint pulse = `estimated-vf-fps` only (drop `video-bitrate` fake); sample fps outside demuxer probe lock | ✅ |
| 8 | I199-T08 | Detector 2b: MediaKit live soft-reopen on paint stall even when cache is healthy; `_streamWorking` requires recent paint for MediaKit live | ✅ |
| 9 | I199-T09 | Continuity-proxy open: disable lavf `reconnect_*` on loopback — proxy owns CDN closes | ✅ |
| 10 | I199-T10 | VO-freeze: one live-edge snap then `_recreatePlayer` if paint still dead (not snap-only ladder) | ✅ |
| 11 | I199-T11 | Paint stall: 2 consecutive `estimated-vf-fps` misses; `frame-drop-count` secondary for false-neg | ✅ |
| 12 | I199-T12 | Adaptive demuxer/fps `getProperty` rate when healthy; Buffering chrome setState debounce | ✅ |
| 13 | I199-T13 | Engine split into tunables/proxy/watchdog/recovery `part of` files (move-only) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I199-A01 | Android TV MediaKit live: when cache runs dry, **Buffering…** appears and playback resumes after refill (or soft reconnect) — no silent frozen frame | ⬜ |
| 2 | I199-A02 | Android TV MediaKit live: **Reload** stays on MediaKit — does not flip to ExoPlayer unless the user picks Exo in **Player** | ⬜ |
| 3 | I199-A03 | Healthy live channel still plays without reconnect thrash from proxy keepalives (no false “dead” every few seconds) | ⬜ |
| 4 | I199-A04 | IPTV Movies/Series (VOD) format hard-open can still one-shot swap engines | ⬜ |
| 5 | I199-A05 | Android TV MediaKit live: no clockwork ~5–6s micro-freeze on healthy channels (CDN reopen play-through) | ⬜ |
| 6 | I199-A06 | Android TV MediaKit live: frozen picture with demuxer cache still ~30s shows **Buffering…** and soft-reconnects within ~5–8s — does not sit on last frame forever | ⬜ |
| 7 | I199-A07 | Android TV MediaKit live: VO-freeze path runs one snap then recreate — does not loop snap-only | ⬜ |

---

## Summary

**Symptom:** On Android TV IPTV with MediaKit, a live channel could stall with empty cache and **no Buffering banner**. **Reload** sometimes restarted on **ExoPlayer** without the user changing the engine. Later report: same silent **frozen frame while demuxer cache stays ~30s** and the feed is still healthy.

**Root cause:**

1. Live MediaKit used `cache-pause=no` ([I148-T20](148-[open]-iptv-live-edge-snap-reconnect-loop.md)) so underrun kept “playing” on a frozen frame instead of pausing to refill.
2. Continuity-proxy / demuxer feed ticks marked the stream “alive”, so the Buffering chrome gate and Stable recovery treated a frozen picture as healthy — including when cache was **full** (healthy cushion + feed ⇒ `_playheadRecentlyMoved` / `_streamWorking`).
3. MediaKit “failed to recognize file format” after Reload / empty reopen auto-swapped to Exo on **live** (no live/VOD gate).
4. Detector 2b only ran when cache was empty, so a `mediacodec_embed` VO stall with a full demuxer never soft-reopened.

**Fix (T02–T04):** Never auto-swap engines on live, and stop counting empty-cache feed ticks as playhead / healthy so watchdog Buffering + soft-reopen still work.

**Regression (T01 → T05):** T01’s `cache-pause=yes` turned every continuity-proxy CDN reopen (~5–6s on chatty Xtream panels, while skipping 3MiB overlap) into a hard micro-pause — stutter on **every** live stream with no Buffering banner. T05 restores live `cache-pause=no` / `demuxer-max-back-bytes=0` (play through demuxer cushion); T03/T04 remain the empty-cache chrome path.

**VO freeze with full cache (T06–T08):** Alive = recent position tick or `estimated-vf-fps ≥ 1` only. MediaKit live `_streamWorking` requires that pulse. Detector 2b soft-reopens after ~5s paint stall even when `demuxer-cache-duration` is still ~30s.

**ATV perf slice (T09–T12):** Height/bitrate live cache tiers + 32 MiB Player buffer on ATV live ([163](163-[open]-android-tv-iptv-vod-live-profile.md) VOD guard); lavf reconnect off on continuity-proxy; VO-freeze one snap → recreate; adaptive watchdog probes. No cheap mid-stream VO reset in media_kit — full Player recreate after snap (documented in T10).

**Engine organization (T13):** Move-only split — `_IptvPtPlayerEngineCore` + `iptv_pt_player_mk_tunables.dart` / `live_proxy` / `watchdog` / `recovery` / orchestration `engine`. Shared fields on Core; cross-calls via abstract stubs on sibling mixins. No behavior change.

**Device smoke (acceptance A01–A07, I150-A01–A04, I128 regression):** Not run in CI — mark acceptance ✅ only after Android TV box verification.

**Related:** [issue 148](148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [issue 128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) (Reload ANR watch) · [issue 150](150-[open]-atv-iptv-4k-mediakit-stutter.md) (cache tiers I150-T05)
