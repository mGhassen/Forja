# RFC-038: Simple streaming resolve (experimental)

**Status:** open  
**Depends on:** [RFC-032](032-[open]-rust-resolver-engine.md), [RFC-030](030-[open]-playback-selection-engine.md)  
**Area:** `apps/forja/lib/shared/playback/`, details Play, player open

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **1 / 5** acceptance |
| **Current slice** | Toggle + SimpleStreamingResolve + streamsPrevalidated wired — device smoke pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R38-C01 | Settings toggle — Simple resolve (experimental) | ✅ |
| 2 | R38-C02 | `SimpleStreamingResolve` — provider → filter → probe → first playable | ✅ |
| 3 | R38-C03 | Player `streamsPrevalidated` — open once, no Auto re-race on exhaust | ✅ |

---

## Acceptance (experimental slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R38-A01 | Toggle off → existing race / failover unchanged | ⬜ |
| 2 | R38-A02 | Toggle on + Auto: try providers one-by-one; probe before open; open player once | ⬜ |
| 3 | R38-A03 | Toggle on + pinned provider: only that provider; stream-by-stream after filter+probe | ⬜ |
| 4 | R38-A04 | HOTD `94997` S1E1 with toggle on reaches video without player reload thrash | ⬜ |
| 5 | R38-A05 | Feature doc + changelog mention the experimental toggle | ✅ |

---

## Summary

The production webstreaming path races hosts, opens the player early, and probes/reloads per source. This RFC adds a **detached** experimental path:

1. Pick provider (Auto order or pinned)
2. Resolve that provider’s multi-streams
3. Filter junk (wrong ep, zip, unplayable)
4. Probe off-player until one is reachable
5. Open player **once** with prevalidated sources; hop streams without Auto re-race

Old `PlaybackEngine` race stays when the toggle is off.
