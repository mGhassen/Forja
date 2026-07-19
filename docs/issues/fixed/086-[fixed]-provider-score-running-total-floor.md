# 086 — Provider score re-sums title nets (Auto fails bury ups)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/resolver-engine/src/health_store.rs`, `ProviderScoreMemory`, anime Source badge

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I86-T01 | Persist running provider `tot` — apply ±delta with floor 0 | ✅ |
| 2 | I86-T02 | Mirror in Dart local/test `ProviderScoreMemory` | ✅ |
| 3 | I86-T03 | Rust + Dart tests: fails at 0 then +4 → global 4 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I86-A01 | Provider Σ counts up and down; never below 0 | ✅ |
| 2 | I86-A02 | Anime Auto fail spam at 0 does not block a later success from raising Σ | ✅ |

---

## Summary

Global Σ was recomputed as **sum of per-title nets** then floored. Anime Auto writes many extract fails (`−2` per host/episode), so raw Σ went deeply negative; a later `+4` still left the badge at **0** next to **+2 +2**.

**Root fix:** Keep a running provider total (`tot`). Each title verdict change applies `Δ` with `max(0, tot + Δ)`. Fails while at 0 are no-ops for Σ; ups still count. Per-title ± prefixes unchanged.

## Related

- [076](076-[fixed]-provider-score-negatives-floored.md) — fails still reduce Σ when above 0
- [042](042-[fixed]-provider-reliability-not-global.md) — global provider reliability
- [stream-providers](../../features/sources/stream-providers.md)
