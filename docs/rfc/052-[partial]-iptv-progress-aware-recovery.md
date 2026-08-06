# RFC-052 — Progress-aware IPTV playback recovery

**Status:** partial
**Depends on:** [issue 148](../issues/148-[open]-iptv-live-edge-snap-reconnect-loop.md) · [issue 124](../issues/fixed/124-[fixed]-atv-iptv-reconnect-banner.md) · [issue 128](../issues/128-[open]-android-tv-iptv-mediakit-exit-anr.md)
**Area:** IPTV / playback

## Status at a glance

| | |
|--|--|
| **Progress** | **13 / 14** components · **1 / 10** acceptance |
| **Current slice** | **Cache-gated recovery** — auto-reconnect only when cache empty and feed dead; ≥2s buffer = working |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R52-C01 | `demuxer-cache-time` probe sampled once per watchdog tick, fire-and-forget so a wedged mpv cannot block the tick | ✅ |
| 2 | R52-C02 | `_networkStillFeeding` predicate + probe reset on every (re)open | ✅ |
| 3 | R52-C03 | Bounded exponential-backoff reconnect controller replacing the fixed `_backoffMs` ladder, collapsing bursts into one pending attempt | ⬜ |
| 4 | R52-C04 | Unify the Exo backend onto the same signal — `_noteFeedProgress` fed from the Exo progress heartbeat, the mpv `buffer` stream, and `demuxer-cache-time` | ✅ |
| 5 | R52-C05 | Blind-probe fallback: `_everSawFeed` false ⇒ `_blindFreezeGrace` (20 s) instead of the 8 s trigger, so a backend the probe cannot read degrades to patient rather than to the original bug | ✅ |
| 6 | R52-C06 | Timeout on the property read so a wedged mpv cannot latch `_cacheProbeInFlight` and blind the probe permanently | ✅ |
| 7 | R52-C07 | Gate detector 3 (silent self-pause, 3 s → hard reconnect) on the same signal | ✅ |
| 8 | R52-C08 | `_logStallSuppressed` traces held stalls every 5 s so the gate is observable in logs | ✅ |
| 9 | R52-C09 | **Single owner of retry** — `_noteSocketTrouble` defers to ffmpeg's own reconnect for `_ffmpegReconnectGrace` (8 s) instead of force-recreating the player on an ffmpeg *warning* | ✅ |
| 10 | R52-C10 | Watchdog holds all detectors while `_socketTroublePending`, so the timers cannot recreate the player mid-reconnect | ✅ |
| 11 | R52-C11 | Deferred escalation aborts when `_openedAt` changed, so it cannot fire against a session that was already replaced | ✅ |
| 12 | R52-C12 | **Live mid-stream: no timer recovery** — after first frame, skip detectors 1–3; live socket notes never escalate; Exo `ended` on live does not forceHard | ✅ |
| 13 | R52-C13 | **Hard chokepoint** — `_triggerRecovery` refuses live auto-restart after first frame unless `userInitiated`; live mid-stream mpv/Exo errors and hw-decode blips are ignored (no reopen) | ✅ |
| 14 | R52-C14 | **Cache gate (correct rule)** — `_streamWorking` = `demuxer-cache-duration` ≥ 2s OR feed advancing OR playhead moving; auto-recovery skipped when working; recovers when cache empty | ✅ |

---

## Acceptance (progress-gate slice)

| # | ID | Description | Status |
|--:|----|----|-----|
| 1 | R52-A01 | Stall detectors 1 and 2 consult `_networkStillFeeding` before calling `_triggerRecovery` | ✅ |
| 2 | R52-A02 | Live channel surviving a >8 s upstream hiccup refills and continues without a "Reconnecting…" banner | ⬜ |
| 3 | R52-A03 | Genuinely dead socket (pull the network) still recovers — demuxer goes quiet, detector fires within ~11 s | ⬜ |
| 4 | R52-A04 | Wedged decoder (feed alive, picture frozen) still reopens at the `_feedingWedgeCeiling` | ⬜ |
| 5 | R52-A05 | Android TV MediaKit: no regression in exit ANR (`I128-A01`) or reconnect banner (`I124-A01`) | ⬜ |
| 6 | R52-A06 | Exo backend live channel gets the same protection — `[IPTV Watchdog] … feed alive, holding` appears instead of a reconnect | ⬜ |
| 7 | R52-A07 | Detector 3 no longer hard-reconnects an Exo rebuffer after 3 s | ⬜ |
| 8 | R52-A08 | Logs show `mark=` advancing on both backends, confirming the probe is not blind | ⬜ |
| 9 | R52-A09 | A dropped socket that ffmpeg recovers logs `ffmpeg reconnected on its own - no restart` and shows **no** banner | ⬜ |
| 10 | R52-A10 | A socket ffmpeg cannot recover still reconnects, ~8 s later than before | ⬜ |

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

The probe can only ever suppress a recovery it has positive evidence against.

### Why the v1.3.148 slice did not fix the report

The first cut read `demuxer-cache-time` only, and `_sampleDemuxerProgress`
returns early when `_exoBackend` is set — so on ExoPlayer the gate never
engaged and the 8 s trigger stayed exactly as it was. Two further holes made it
fragile even on mpv:

| Hole | Effect | Fix |
|---|----|---|
| Exo never sampled | Gate inert on Exo | `R52-C04` — feed from the Exo progress heartbeat. `_buffered` could not be reused: it is only assigned when `duration > 0`, and live streams report none. |
| No sample ⇒ "dead" | A blind probe reproduced the original bug exactly | `R52-C05` — blind ⇒ 20 s grace |
| `_cacheProbeInFlight` latch | A hung property read blinded the probe for the rest of the session | `R52-C06` — 4 s timeout |
| Detector 3 ungated | 3 s of `playing=false` ⇒ hard reconnect | `R52-C07` |

## Three layers owned retry; the top one kept winning

This is the cause that survived both earlier slices, because it never goes
through the watchdog at all.

| Layer | Retry policy | Set where |
|---|----|----|
| libavformat | `reconnect=1`, `reconnect_at_eof=1`, `reconnect_streamed=1`, `reconnect_delay_max=5`, `reconnect_on_network_error=1` | `stream-lavf-o` in `_applyMpvTunables` |
| mpv | `keep-open=yes`, `network-timeout=15` | `_applyMpvTunables` |
| Forja | 4 watchdog detectors + error listener + log listener → `_triggerRecovery` | `iptv_pt_player_engine.dart` |

When an IPTV socket drops, ffmpeg logs

```
[ffmpeg/network] http: Will reconnect at 12345, error=Connection reset by peer.
```

at **warning** level and then reconnects transparently, usually within a second
or two. The log listener matched `connection reset` on any `warn` line and
called `_triggerRecovery(forceHard: true)` — recreating the whole player on top
of a recovery that was already succeeding. The user-visible result is a channel
that plays fine and then drops into "Reconnecting…" for no reason, on a
schedule set by how often the portal cycles its sockets.

**Contract now:** auto-recovery runs only when the stream is **not** working.
Working = `demuxer-cache-duration` (or Exo buffered ahead) ≥ 2 seconds, or the
feed mark still advancing, or the playhead moved in the last 2 seconds. Timers
and socket logs no longer reopen a session that still has cache. Reload always
restarts. Truly empty cache + dead feed still reconnects.

## Related

- Lume's `PlaybackRetryController` (bounded backoff `[1,2,4,8,8,8]`, reset on
  confirmed-healthy, one pending attempt per outage) is the reference for
  `R52-C03`. Reference design only — different language and engine, no shared
  code.
- Lume reaches the same discrimination differently: it reconnects off KSPlayer's
  `.error` state and arms its stall watchdog **only** while the engine reports
  `.buffering`, cancelling it the moment the state changes. Forja's watchdog is
  a free-running 1 s timer, so it needs the probe to get the same information.
