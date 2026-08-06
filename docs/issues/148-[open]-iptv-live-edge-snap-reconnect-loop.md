# 148 — IPTV live-edge snap flushes an empty cache into a reconnect loop

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart` · media_kit / libmpv  
**Reported:** 2026-08-05

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 7** acceptance |
| **Current slice** | Playback restored to `v1.3.114` semantics (`I148-T08`); [RFC-052](../rfc/canceled/052-[canceled]-iptv-progress-aware-recovery.md) canceled — device smoke outstanding |

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
| 7 | I148-T07 | **Hypothesis shipped then abandoned** — assumed 8 s freeze vs 30 s cache; [RFC-052](../rfc/canceled/052-[canceled]-iptv-progress-aware-recovery.md) gated detectors on feed/cache progress. Did not stop the reporter's reconnect loop | ✅ |
| 8 | I148-T08 | **Abandon RFC-052** — strip progress/cache/ffmpeg-grace gates; restore `v1.3.114` tunables + watchdog/error recovery; keep PiP / menus / Exo / open serialization; cancel RFC-052 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-A01 | Desktop MediaKit: live Xtream channel plays 10+ minutes without periodic "Reconnecting… (1/8)" on a healthy feed | ⬜ |
| 2 | I148-A02 | Log has no mid-stream `live-edge snap` / underrun-exit flush — only seekable open jump-to-live (v1.3.114) | ⬜ |
| 3 | I148-A03 | Genuinely dead feed still escalates: banner appears, retry ladder runs, source rotates | ⬜ |
| 4 | I148-A04 | Player **Reload** soft-reopens the current source (same as open) and recovers a stalled channel without ANR | ⬜ |
| 5 | I148-A05 | Android TV MediaKit: **Reload** on a stalled channel reconnects and the app stays alive (no ANR — issue 128 T08 regression watch) | ⬜ |
| 6 | I148-A06 | Android TV MediaKit: Exo → MediaKit via Player menu, then **Reload** — no ANR (`I128-A01` path) | ⬜ |
| 7 | I148-A07 | Android TV MediaKit: live channel plays as steadily as it did on `v1.3.114` — no periodic buffering / "Reconnecting…" | ⬜ |

---

## Summary

**Symptom (1.3.135+):** A live IPTV channel plays normally, then after ~1–2 minutes the picture stalls, the buffering spinner shows `Reconnecting… (attempt 1/8)`, and playback may resume on its own. The upstream feed is often still alive.

> **Status update (I148-T08).** [RFC-052](../rfc/canceled/052-[canceled]-iptv-progress-aware-recovery.md) progress/cache gates and hard-blocks did not fix the report (symptom delayed or dead streams never recovered). **Playback/recovery code is restored to `v1.3.114` semantics.** Keep PiP, Player menus, Exo TextureView/ATV, volume map, and open serialization. **Do not re-land RFC-052 without a log capture that proves a new root cause.**

> **Status update (I148-T07).** The 8 s vs 30 s theory was implemented as RFC-052; it is **historical** — not confirmed by the reporter. T07 stays ✅ as "work that shipped"; the approach is canceled, not proven.

> **Status update (I148-T06).** The live-edge snap / drift-gate theory was **not confirmed**. The drift gate shipped in `v1.3.141` and the reporter's stall was unchanged. Analysis kept for mechanism; do not re-apply without logs.

**Original (unconfirmed) theory — the recovery path fed itself.** Traced to commit `893dfaeb` ("Improve IPTV player behavior"), which added a mid-stream live-edge snap on every buffering exit:

1. `_scheduleJumpToLive(reason: 'underrun exit')` fires whenever `buffering` clears after ≥ 800 ms mid-stream.
2. On a non-seekable pure-live TS (every Xtream `.ts` feed — `_probeStreamCapabilities` needs `seekable=yes` **and** `duration > 0`) the snap runs `drop-buffers`, discarding mpv's entire demuxer cache.
3. media_kit derives `buffering` from mpv's **`core-idle`**, not `paused-for-cache` (`media_kit/lib/src/player/native/player/real.dart` L1517–1534). `cache-pause=no` therefore does not prevent it: an empty cache leaves nothing decoded, `core-idle` flips true, and media_kit reports buffering again.
4. That refill is realtime-bound on a live feed, so it lasts well past 800 ms → the buffering-exit handler snaps again (throttled only to one per 2.5 s by `_lastLiveJumpAt`).
5. Once a single buffering window exceeds watchdog detector 1's 12 s grace, `_triggerRecovery` runs and paints `Reconnecting… (attempt 1/8)`.

So one ordinary upstream hiccup was amplified into a 12 s+ stall plus a reconnect banner. The cushion that exists to absorb hiccups was being thrown away at exactly the moment it was needed.

Watchdog detector 2 (position frozen > 8 s) called the same snap, so it compounded the loop and — once the snap became conditional — could retry forever on a dead feed without ever escalating.

**Attempted fix (reverted in T06):** Read `demuxer-cache-duration` before snapping. On a realtime feed it stays near zero unless mpv kept downloading through a stall, so it is the only honest drift signal on a non-seekable TS. Below `_liveDriftSecs` (6 s) we are already at the edge and the flush is skipped. Detector 2 now gets two snap attempts before escalating to a real reconnect, and the counter resets as soon as the position stream ticks.

**Shipped regression (I148-T04) — reached users in `v1.3.141`.** The first cut of the drift gate matched on `reason != 'open'`, which also caught `'manual reload'`. On a healthy stream `demuxer-cache-duration` is near zero, so the player **Reload** button became a silent no-op. Fixed later via `force:` / escalate — then stripped again with T08 when returning to v1.3.114 soft reopen.

**Not fixed here:** a proven engine-level root cause beyond restoring known-good player semantics. Device smoke (`I148-A01`–`A07`) is the gate.

**Related:** [092](092-[open]-windows-iptv-stream-freeze-after-20s.md) (Windows freeze / watchdog detectors) · [124](124-[open]-android-tv-iptv-reconnect-banner-stuck.md) (banner clearing) · [138](138-[open]-android-tv-iptv-4k-audio.md) · [RFC-052 canceled](../rfc/canceled/052-[canceled]-iptv-progress-aware-recovery.md)

## Verify

1. Build a **new** desktop/ATV package from this commit — do not judge on older 1.3.x installs
2. Play a live Xtream channel for 10+ minutes on MediaKit
3. Confirm no periodic `Reconnecting… (attempt N/8)` while the feed is healthy
4. Kill the upstream (or pick a dead channel) — the banner and retry ladder must still fire
5. **Reload** soft-reopens and recovers without ANR on ATV
