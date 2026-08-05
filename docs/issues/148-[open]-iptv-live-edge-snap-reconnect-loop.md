# 148 — IPTV live-edge snap flushes an empty cache into a reconnect loop

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart` · media_kit / libmpv  
**Reported:** 2026-08-05

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-T01 | Gate mid-stream live-edge snap on measured drift (`demuxer-cache-duration` ≥ `_liveDriftSecs`) — never flush an empty cache | ✅ |
| 2 | I148-T02 | Bound watchdog detector 2 to 2 consecutive snaps, then escalate to `_triggerRecovery` (`_frozenSnapAttempts`) | ✅ |
| 3 | I148-T03 | Reset `_frozenSnapAttempts` when the position stream ticks again | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-A01 | Desktop MediaKit: live Xtream channel plays 10+ minutes; brief upstream hiccups stay sub-second, no "Reconnecting… (1/8)" banner | ⬜ |
| 2 | I148-A02 | Log shows `live-edge snap skipped (underrun exit)` after a hiccup, not a repeating `live-edge snap` | ⬜ |
| 3 | I148-A03 | Genuinely dead feed still escalates: banner appears, retry ladder runs, source rotates | ⬜ |

---

## Summary

**Symptom (1.3.135):** A live IPTV channel plays normally, then after ~1 minute the picture stalls, the buffering spinner shows `Reconnecting… (attempt 1/8)`, and playback resumes on its own a few seconds later. The upstream feed is alive — the stream comes back without changing source.

**Root cause — the recovery path fed itself.** Introduced by commit `893dfaeb` ("Improve IPTV player behavior"), which added a mid-stream live-edge snap on every buffering exit:

1. `_scheduleJumpToLive(reason: 'underrun exit')` fires whenever `buffering` clears after ≥ 800 ms mid-stream.
2. On a non-seekable pure-live TS (every Xtream `.ts` feed — `_probeStreamCapabilities` needs `seekable=yes` **and** `duration > 0`) the snap runs `drop-buffers`, discarding mpv's entire demuxer cache.
3. media_kit derives `buffering` from mpv's **`core-idle`**, not `paused-for-cache` (`media_kit/lib/src/player/native/player/real.dart` L1517–1534). `cache-pause=no` therefore does not prevent it: an empty cache leaves nothing decoded, `core-idle` flips true, and media_kit reports buffering again.
4. That refill is realtime-bound on a live feed, so it lasts well past 800 ms → the buffering-exit handler snaps again (throttled only to one per 2.5 s by `_lastLiveJumpAt`).
5. Once a single buffering window exceeds watchdog detector 1's 12 s grace, `_triggerRecovery` runs and paints `Reconnecting… (attempt 1/8)`.

So one ordinary upstream hiccup was amplified into a 12 s+ stall plus a reconnect banner. The cushion that exists to absorb hiccups was being thrown away at exactly the moment it was needed.

Watchdog detector 2 (position frozen > 8 s) called the same snap, so it compounded the loop and — once the snap became conditional — could retry forever on a dead feed without ever escalating.

**Fix:** Read `demuxer-cache-duration` before snapping. On a realtime feed it stays near zero unless mpv kept downloading through a stall, so it is the only honest drift signal on a non-seekable TS. Below `_liveDriftSecs` (6 s) we are already at the edge and the flush is skipped. Detector 2 now gets two snap attempts before escalating to a real reconnect, and the counter resets as soon as the position stream ticks.

**Not fixed here:** the upstream hiccup itself. On a pure realtime feed the cushion is only whatever the panel bursts ahead of realtime, so a genuine multi-second upstream stall is still visible. This issue is about not amplifying it.

**Related:** [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) (Windows freeze / watchdog detectors) · [124](124-[open]-android-tv-iptv-reconnect-banner-stuck.md) (banner clearing) · [138](138-[open]-android-tv-iptv-4k-audio.md)

## Verify

1. Desktop build, play a live Xtream channel for 10+ minutes
2. Watch the debug log for `[IPTV Player] live-edge snap` lines — mid-stream ones should read `skipped … already at edge`
3. Confirm no `Reconnecting… (attempt N/8)` banner while the feed is healthy
4. Kill the upstream (or pick a dead channel) — the banner and retry ladder must still fire
