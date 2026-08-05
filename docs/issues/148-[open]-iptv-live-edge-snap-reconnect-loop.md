# 148 — IPTV live-edge snap flushes an empty cache into a reconnect loop

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart` · media_kit / libmpv  
**Reported:** 2026-08-05

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 7** acceptance |
| **Current slice** | Reverted to `v1.3.114` playback, then fixed the real cause in [RFC-052](../rfc/052-[partial]-iptv-progress-aware-recovery.md) — device smoke outstanding |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-T01 | Gate mid-stream live-edge snap on measured drift (`demuxer-cache-duration` ≥ `_liveDriftSecs`) — never flush an empty cache | ✅ |
| 2 | I148-T02 | Bound watchdog detector 2 to 2 consecutive snaps, then escalate to `_triggerRecovery` (`_frozenSnapAttempts`) | ✅ |
| 3 | I148-T03 | Reset `_frozenSnapAttempts` when the position stream ticks again | ✅ |
| 4 | I148-T04 | Exempt user intent from the drift gate — `_scheduleJumpToLive(force:)`; manual reload also bypasses the 2.5 s throttle | ✅ |
| 5 | I148-T05 | Manual reload escalates to a real reopen when the flush leaves frames frozen (`_escalateReloadIfStalled` → `_triggerRecovery` reopen tier) | ✅ |
| 6 | I148-T06 | **Revert** T01–T03: drift gate did not fix the reported stall in `v1.3.141`. Restore `v1.3.114` playback semantics — `demuxer-max-back-bytes` 25 MB, no per-open override, no `live_start_index`, no mid-stream live-edge snap, detector 2 back to `_triggerRecovery`, recovery tier ≤2 back to soft reopen | ✅ |
| 7 | I148-T07 | **Root cause found** — the 8 s frozen-position detector contradicts `cache-secs=30`, so any hiccup deeper than 8 s reopened a feed that was still refilling. Fixed in [RFC-052](../rfc/052-[partial]-iptv-progress-aware-recovery.md) by gating the stall detectors on `demuxer-cache-time` progress | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-A01 | Desktop MediaKit: live Xtream channel plays 10+ minutes; brief upstream hiccups stay sub-second, no "Reconnecting… (1/8)" banner | ⬜ |
| 2 | I148-A02 | Log shows `live-edge snap skipped (underrun exit)` after a hiccup, not a repeating `live-edge snap` | ⬜ |
| 3 | I148-A03 | Genuinely dead feed still escalates: banner appears, retry ladder runs, source rotates | ⬜ |
| 4 | I148-A04 | Player **Reload** on a healthy live channel still flushes and rejoins the edge (drift gate does not swallow user intent) | ⬜ |
| 5 | I148-A05 | Android TV MediaKit: **Reload** on a stalled channel reconnects within ~4 s and the app stays alive (no ANR — issue 128 T08 regression watch) | ⬜ |
| 6 | I148-A06 | Android TV MediaKit: Exo → MediaKit via Player menu, then **Reload** — no ANR (`I128-A01` path) | ⬜ |
| 7 | I148-A07 | Android TV MediaKit: live channel plays as steadily as it did on `v1.3.114` — no periodic buffering / "Reconnecting…" | ⬜ |

---

## Summary

**Symptom (1.3.135):** A live IPTV channel plays normally, then after ~1 minute the picture stalls, the buffering spinner shows `Reconnecting… (attempt 1/8)`, and playback resumes on its own a few seconds later. The upstream feed is alive — the stream comes back without changing source.

> **Root cause (I148-T07).** The 8 s frozen-position detector contradicted
> `cache-secs=30`: mpv was told to hold a 30 s cache, then declared dead after
> 8 s of frozen position, so every upstream hiccup deeper than 8 s forced a
> reopen **mid-refill**. The reopen threw away the partly-filled cache and
> underran again — the "plays a minute, then Reconnecting…" loop. Fixed in
> [RFC-052](../rfc/052-[partial]-iptv-progress-aware-recovery.md) by gating the
> stall detectors on `demuxer-cache-time` progress. Predates 2026-08-05; the
> live-edge snap work only made it fire more often.

> **Status update (I148-T06).** The theory below was **not confirmed**. The drift gate shipped in `v1.3.141` and the reporter's stall was unchanged, so flushing an empty cache was not the cause — or not the only one. All playback tuning and recovery semantics have been reverted to `v1.3.114` (the last build the reporter considered good). The analysis is kept because the mechanism is real and reachable; it just is not the reported bug. **Do not re-apply any of it without a log capture first.**

**Original (unconfirmed) theory — the recovery path fed itself.** Traced to commit `893dfaeb` ("Improve IPTV player behavior"), which added a mid-stream live-edge snap on every buffering exit:

1. `_scheduleJumpToLive(reason: 'underrun exit')` fires whenever `buffering` clears after ≥ 800 ms mid-stream.
2. On a non-seekable pure-live TS (every Xtream `.ts` feed — `_probeStreamCapabilities` needs `seekable=yes` **and** `duration > 0`) the snap runs `drop-buffers`, discarding mpv's entire demuxer cache.
3. media_kit derives `buffering` from mpv's **`core-idle`**, not `paused-for-cache` (`media_kit/lib/src/player/native/player/real.dart` L1517–1534). `cache-pause=no` therefore does not prevent it: an empty cache leaves nothing decoded, `core-idle` flips true, and media_kit reports buffering again.
4. That refill is realtime-bound on a live feed, so it lasts well past 800 ms → the buffering-exit handler snaps again (throttled only to one per 2.5 s by `_lastLiveJumpAt`).
5. Once a single buffering window exceeds watchdog detector 1's 12 s grace, `_triggerRecovery` runs and paints `Reconnecting… (attempt 1/8)`.

So one ordinary upstream hiccup was amplified into a 12 s+ stall plus a reconnect banner. The cushion that exists to absorb hiccups was being thrown away at exactly the moment it was needed.

Watchdog detector 2 (position frozen > 8 s) called the same snap, so it compounded the loop and — once the snap became conditional — could retry forever on a dead feed without ever escalating.

**Attempted fix (reverted in T06):** Read `demuxer-cache-duration` before snapping. On a realtime feed it stays near zero unless mpv kept downloading through a stall, so it is the only honest drift signal on a non-seekable TS. Below `_liveDriftSecs` (6 s) we are already at the edge and the flush is skipped. Detector 2 now gets two snap attempts before escalating to a real reconnect, and the counter resets as soon as the position stream ticks.

**Shipped regression (I148-T04) — reached users in `v1.3.141`.** The first cut of the drift gate matched on `reason != 'open'`, which also caught `'manual reload'`. On a healthy stream `demuxer-cache-duration` is near zero, so the player **Reload** button became a silent no-op. `v1.3.141` contains the drift gate but **not** the `force:` exemption, so Reload is dead for live channels on that build. The gate is now opt-out via `force:`, and user intent bypasses both the gate and the 2.5 s throttle — this needs a patch release to reach users.

**Reload now reconnects for real (I148-T05).** Previously **Reload** on live MediaKit only flushed buffers — it never reopened the HTTP connection, so it could not revive a dead channel. It cannot simply call `Player.open`: [128](128-[open]-android-tv-iptv-mediakit-exit-anr.md) T08 recorded an ATV ANR from exactly that, and the T08 follow-up recorded a second ANR from a pre-open `stop()` on a virgin player.

The compromise: keep the cheap flush as the first move, then check whether the position stream resumed. If it did (the healthy case, and the one that ANR'd in T08) nothing further happens. If frames are still frozen, escalate into `_triggerRecovery(forceHard: true)` — which at `_retryAttempt == 1` performs `_engineOpenSource` + play with **no** pre-open `stop()`, and hands off to the existing retry ladder if it keeps failing. So the reopen only runs on an already-stalled player, which is precisely when the watchdog would have reopened anyway; no new risk class is introduced, and the virgin-`stop()` path is never taken.

**Not fixed here:** the upstream hiccup itself. On a pure realtime feed the cushion is only whatever the panel bursts ahead of realtime, so a genuine multi-second upstream stall is still visible. This issue is about not amplifying it.

**Related:** [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) (Windows freeze / watchdog detectors) · [124](124-[open]-android-tv-iptv-reconnect-banner-stuck.md) (banner clearing) · [138](138-[open]-android-tv-iptv-4k-audio.md)

## Verify

1. Desktop build, play a live Xtream channel for 10+ minutes
2. Watch the debug log for `[IPTV Player] live-edge snap` lines — mid-stream ones should read `skipped … already at edge`
3. Confirm no `Reconnecting… (attempt N/8)` banner while the feed is healthy
4. Kill the upstream (or pick a dead channel) — the banner and retry ladder must still fire
