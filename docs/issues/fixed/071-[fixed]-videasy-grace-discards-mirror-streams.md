# 071 — Videasy grace cutoff discards collected mirror streams

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Videasy host extraction · player Servers panel

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 3** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I71-T01 | Distinguish the intentional eight-second mirror grace cutoff from external extraction cancellation | ✅ |
| 2 | I71-T02 | Preserve and return every responsive Videasy mirror collected before the cutoff | ✅ |
| 3 | I71-T03 | Add regression coverage for grace cutoff, external cancellation, and empty results | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I71-A01 | Unit: grace-triggered generation cancellation keeps already-collected mirror hits | ✅ |
| 2 | I71-A02 | Unit: external cancellation and empty extraction still return no result | ✅ |
| 3 | I71-A03 | Manual: checking Videasy expands all responsive named mirrors in the player Servers panel | ⬜ |

---

## Summary

Videasy probes its named mirrors concurrently and starts an eight-second grace period after the first success. Grace expiry stopped hung sibling requests by advancing the extractor generation, but the result gate interpreted that internal generation change as external cancellation and discarded every mirror already collected. The host adapter then used its WebView fallback, which commonly returned only one stream.

The root fix keeps the latency cap and distinguishes intentional grace expiry from user/session cancellation. Responsive mirrors collected during the grace period now reach the player as separate named streams; mirrors that hang past the cutoff remain absent.

## Related

- [041](041-[fixed]-videasy-hangs-before-cdn-yoru.md) — introduced the bounded post-hit mirror grace period
- [Stream providers](../../features/sources/stream-providers.md)
