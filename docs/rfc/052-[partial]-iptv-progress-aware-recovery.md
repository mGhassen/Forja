# RFC-052 — Progress-aware IPTV playback recovery

**Status:** partial
**Depends on:** [issue 148](../issues/148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [issue 124](../issues/fixed/124-[fixed]-atv-iptv-reconnect-banner.md) · [issue 128](../issues/128-[open]-android-tv-iptv-mediakit-exit-anr.md)
**Area:** IPTV / playback

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 4** components · **1 / 6** acceptance (progress-gate slice) |
| **Current slice** | Demuxer progress probe + gated stall detectors landed — backoff controller not started |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R52-C01 | `demuxer-cache-time` probe sampled once per watchdog tick, fire-and-forget so a wedged mpv cannot block the tick | ✅ |
| 2 | R52-C02 | `_networkStillFeeding` predicate + probe reset on every (re)open | ✅ |
| 3 | R52-C03 | Bounded exponential-backoff reconnect controller replacing the fixed `_backoffMs` ladder, collapsing bursts into one pending attempt | ⬜ |
| 4 | R52-C04 | Unify the Exo backend onto the same signal (ExoPlayer buffered-position delta stands in for `demuxer-cache-time`) | ⬜ |

---

## Acceptance (progress-gate slice)

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R52-A01 | Stall detectors 1 and 2 consult `_networkStillFeeding` before calling `_triggerRecovery` | ✅ |
| 2 | R52-A02 | Live channel surviving a >8 s upstream hiccup refills and continues without a "Reconnecting…" banner | ⬜ |
| 3 | R52-A03 | Genuinely dead socket (pull the network) still recovers — demuxer goes quiet, detector fires within ~11 s | ⬜ |
| 4 | R52-A04 | Wedged decoder (feed alive, picture frozen) still reopens at the `_feedingWedgeCeiling` | ⬜ |
| 5 | R52-A05 | Android TV MediaKit: no regression in exit ANR (`I128-A01`) or reconnect banner (`I124-A01`) | ⬜ |
| 6 | R52-A06 | Exo backend unchanged — probe returns unknown, detectors keep pre-RFC behaviour | ⬜ |

---

## Summary

Forja's IPTV recovery is already error-driven: `player.stream.error` and the mpv
log stream both route into `_triggerRecovery`. The gap is the **timer-based
stall detectors** that sit alongside them. A timer cannot distinguish a dead
socket from a live feed that is refilling, so it guesses — and it guessed wrong
often enough to reopen healthy streams.

## Problem

The player asks mpv to hold a 30 s cache (`cache-secs=30`,
`demuxer-readahead-secs=20`, `cache-pause=no`) and then declares the stream dead
after **8 s** of frozen position:

```
if (_s._lastPos > Duration.zero &&
    now.difference(_s._lastPosChange) > const Duration(milliseconds: 8000)) {
  _triggerRecovery(reason: 'position frozen > 8s');
}
```

Those two settings contradict each other. Any upstream hiccup deeper than 8 s —
routine on IPTV — trips a reopen **while mpv is still successfully pulling
data**. The reopen discards the partly-refilled cache, so the fresh socket
underruns again, and the user sees a channel that plays for a while and then
drops into "Reconnecting… (1/8)".

This predates the 2026-08-05 changes; the live-edge snap work in `893dfaeb`
made it fire more often by flushing the cache mid-stream, which is why the
symptom got worse before it was traced.

## Contract

`demuxer-cache-time` is the timestamp of the last demuxed packet. It advances
only when bytes are arriving **and** parsing, which splits "position stopped"
into the two cases that need opposite handling:

| Position | Demuxer | Meaning | Action |
|---|---|----|----|
| Frozen | Advancing | Feed alive, cache refilling | **Wait** — reopening destroys the refill |
| Frozen | Quiet | Socket dead | Recover (existing ladder) |
| Frozen | Advancing past `_feedingWedgeCeiling` | Wedged decoder | Reopen — nothing else clears it |

Unknown (Exo backend, or no sample yet) counts as **dead**, so the probe can
only ever suppress a recovery it has positive evidence against.

## Related

- Lume's `PlaybackRetryController` (bounded backoff `[1,2,4,8,8,8]`, reset on
  confirmed-healthy, one pending attempt per outage) is the reference for
  `R52-C03`. Reference design only — different language and engine, no shared
  code.
- Lume reaches the same discrimination differently: it reconnects off KSPlayer's
  `.error` state and arms its stall watchdog **only** while the engine reports
  `.buffering`, cancelling it the moment the state changes. Forja's watchdog is
  a free-running 1 s timer, so it needs the probe to get the same information.
