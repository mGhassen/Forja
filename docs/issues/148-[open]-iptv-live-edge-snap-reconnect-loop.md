# 148 — IPTV live-edge snap flushes an empty cache into a reconnect loop

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `iptv_pt_player_engine.dart` · `iptv_pt_player_screen.dart` · media_kit / libmpv  
**Reported:** 2026-08-05

## Status at a glance

| | |
|--|--|
| **Progress** | **21 / 21** fix · **0 / 17** acceptance |
| **Current slice** | Live continuity proxy + macOS/Linux software decode; device smoke outstanding |

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
| 8 | I148-T08 | **Abandon RFC-052 as sole path** — strip progress/cache gates from default; cancel RFC-052 as mandatory approach | ✅ |
| 9 | I148-T09 | **Dual mode** — restore 1.3.170 buffer-aware recovery as default; keep 1.3.114 classic timers; Settings → Playback → IPTV live recovery; applies on next player open | ✅ |
| 10 | I148-T10 | Reject absurd `demuxer-cache-duration` / buffer-ahead samples (>90 s) as PTS garbage — stats show `— (invalid PTS)`; Stable gate does not treat spikes as healthy cache | ✅ |
| 11 | I148-T11 | **Stall-reopen test mode** — Settings third option (`stall`): Stable cache/feed hold, but ignore cache/feed when buffering/freeze past grace with no playhead; debounce `core-idle` flicker on `_bufferingSince` | ✅ |
| 12 | I148-T12 | **Stall UX** — Settings dropdown is Stable/Classic only; **Reopen on buffer stall** is a checkbox under Stable (still stores `stall` / `buffered` / `classic`) | ✅ |
| 13 | I148-T13 | 12s Buffering + frozen playhead forces reconnect on Stable (hard wall; ignores cache/feed hold) | ✅ |
| 14 | I148-T14 | Debounce `core-idle` flicker on `_bufferingSince` for **all** modes (not stall-only) — Stable was zeroing the 12s clock so spinner never became Reconnecting 1/8 | ✅ |
| 15 | I148-T15 | Hard wall requires **weak** cache (`<_minHealthyCacheSecs`) and not feeding — pause-to-refill with a full cushion must not reconnect | ✅ |
| 16 | I148-T16 | Arm 8s transient hw-decode ignore on socket blip, mid-stream Buffering, and live-edge snap — stop VT one-shot → hard software recreate during refill | ✅ |
| 17 | I148-T17 | Live Stable: 15s pause-refill grace; detector 3 never `forceHard` on cache-pause self-pause; no mid-stream `play()` fight with paused-for-cache | ✅ |
| 18 | I148-T18 | Live Stable: hold VT / hw decode fails (no software recreate) — CDN chunk close → corrupt TS is expected; empty-cache detectors still recover dead feeds | ✅ |
| 19 | I148-T19 | Stop fake `working` logs on empty cache; grace only while feeding/cushion; empty pause soft-reopens at 5s + Buffering chrome | ✅ |
| 20 | I148-T20 | Live MediaKit: `cache-pause=no`, `demuxer-max-back-bytes=1MiB`, `reconnect_delay_max=30` — CDN socket closes must not hard-pause; underrun freezes without back-buffer replay | ✅ |
| 21 | I148-T21 | Live MediaKit continuity proxy (localhost TS relay) + macOS/Linux live software decode — CDN closes never reach mpv; no VT death spiral every ~15s | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I148-A01 | Desktop MediaKit + **Stable**: live Xtream channel plays 10+ minutes without periodic "Reconnecting… (1/8)" on a healthy feed | ⬜ |
| 2 | I148-A02 | **Stable**: log shows cache/feed hold (`skip recovery … working`) on hiccups, not mid-stream underrun live-edge snaps | ⬜ |
| 3 | I148-A03 | Genuinely dead feed still escalates on **Stable** and **Classic**: banner appears, retry ladder runs | ⬜ |
| 4 | I148-A04 | Player **Reload** reconnects on both modes (Stable: flush→escalate; Classic: soft reopen) without ANR | ⬜ |
| 5 | I148-A05 | Android TV MediaKit: **Reload** on a stalled channel reconnects and the app stays alive (no ANR — issue 128 T08 regression watch) | ⬜ |
| 6 | I148-A06 | Android TV MediaKit: Exo → MediaKit via Player menu, then **Reload** — no ANR (`I128-A01` path) | ⬜ |
| 7 | I148-A07 | Android TV MediaKit + **Stable**: live channel matches 1.3.170 steadiness | ⬜ |
| 8 | I148-A08 | Settings dropdown switches Stable/Classic; stall checkbox under Stable; next player open logs `live recovery mode=buffered|stall|classic` | ⬜ |
| 9 | I148-A09 | **Classic** mode: frozen-position detector reopens within ~8s without requiring empty cache | ⬜ |
| 10 | I148-A10 | Stream stats: Cache stays in the seconds–tens range on healthy live; a PTS spike shows `— (invalid PTS)` not thousands of minutes; no multi-hour Buffered ahead | ⬜ |
| 11 | I148-A11 | MediaKit + **Stable** + **Reopen on buffer stall**: sustained Buffering with frozen playhead and **empty** cache reconnects within ~12s | ⬜ |
| 12 | I148-A12 | **Stable** + pause-to-refill: Buffering with frozen playhead and **healthy** cache (≥2s) does **not** reconnect; picture stays frozen until refill resumes | ⬜ |
| 13 | I148-A13 | Socket `ends prematurely` + VT one-shot: log shows ignore transient hw fail — no hard software recreate while cache/feed recover | ⬜ |
| 14 | I148-A14 | Genuinely empty cache + Buffering ≥12s still reconnects (hard wall still works when cushion is gone) | ⬜ |
| 15 | I148-A15 | After repeated CDN `ends prematurely`: no `silent self-pause` hard recovery loop; log shows `self-pause` hold / live VT hold; picture resumes without recreate thrash | ⬜ |
| 16 | I148-A16 | Live MediaKit: channel plays through multiple `ends prematurely` without visible pause/reconnect thrash; no silent ~15s replay on underrun | ⬜ |
| 17 | I148-A17 | Live MediaKit logs `[IPTV Proxy] upstream reconnected` on CDN close while picture keeps playing (no mpv `ends prematurely` / self-pause recovery) | ⬜ |

---

## Summary

**Symptom (1.3.135+):** A live IPTV channel plays normally, then after ~1–2 minutes the picture stalls, the buffering spinner shows `Reconnecting… (attempt 1/8)`, and playback may resume on its own. The upstream feed is often still alive.

> **Status update (I148-T21).** ffmpeg-in-mpv reconnect could not absorb Xtream socket closes: buffer dumped, VT failed, soft reopen every ~15s. Live MediaKit now opens a **localhost continuity proxy**; mpv never sees upstream EOF. macOS/Linux live forces software decode (Windows already did).

> **Status update (I148-T20).** Live `cache-pause=yes` made every Xtream HTTP socket close a hard pause (reporter: stop every ~70MB). Reverted to `cache-pause=no` with `demuxer-max-back-bytes=1MiB` (freeze without replay) and `reconnect_delay_max=30` so ffmpeg can bridge closes silently.

> **Status update (I148-T17 / T18).** After T15/T16 the reporter still looped on `silent self-pause, cache empty` hard recreate: CDN closes the HTTP chunk → VT one-shot → `cache-pause` sets `playing=false` with `buffering=false` → detector 3 at 3s. Live Stable now holds 15s pause-refill grace, never forceHard on that path, and does not software-recreate on VT during Stable.

> **Status update (I148-T15 / T16).** Live `cache-pause=yes` made T13's hard wall reconnect while demuxer still held ~28s (pause-to-refill). Hard wall now requires weak cache and not feeding. Socket blips / mid-stream Buffering arm an 8s VT ignore so one-shot `hardware accelerator failed` does not hard-recreate mid-refill.

> **Status update (I148-T14).** T13 never painted **Reconnecting… (1/8)** on default Stable: media_kit `core-idle` flickers `buffering=false` and the listener zeroed `_bufferingSince`. Spinner stayed up until MediaCodec ANR. Debounce (`_bufferingClearHold` 1.5s) now applies to Stable/Classic too, not only the stall checkbox.

> **Status update (I148-T13).** 12s of Buffering with a frozen playhead always reconnects on Stable, even when demuxer cache/feed still look healthy (same as detector 1 mid-stream grace). Cache window stays 30s; the spinner does not sit forever. **Does not fire if `_bufferingSince` is reset every flicker — see T14.**

> **Status update (I148-T12).** Stall reopen is no longer a third dropdown peer next to 1.3.170 / 1.3.114. Settings → **IPTV live recovery** = Stable | Classic; with Stable selected, checkbox **Reopen on buffer stall** maps to stored `stall`.

> **Status update (I148-T11).** Third Settings mode **Stable — reopen on buffer stall (test)** (`stall`): same buffer/feed hold as 1.3.170, but sustained buffering/freeze without playhead movement forces reopen (ignores stale demuxer cache). Default remains Stable (`buffered`).

> **Status update (I148-T09).** Both policies are available: **Stable** = 1.3.170 buffer/feed-aware recovery (default); **Classic** = 1.3.114 stall-timer recovery. Toggle in Settings → Playback → IPTV live recovery. RFC-052 remains canceled as a mandatory sole path; its behavior ships as the Stable mode.

> **Status update (I148-T08).** Full strip to classic-only was superseded by T09 after the reporter confirmed **1.3.170** (buffer-aware) works. Classic remains selectable.

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
