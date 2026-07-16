# 076 — Provider fail verdicts (−2) do not reduce global Σ

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/resolver-engine/src/health_store.rs`, `packages/rust` ProviderScoreMemory, player Source badge

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I76-T01 | Stop flooring per-title totals at 0 in Rust `total_for` | ✅ |
| 2 | I76-T02 | Mirror in Dart `ProviderScoreMemory._totalFor` (local/test path) | ✅ |
| 3 | I76-T03 | Rust + Dart tests: prior Σ 22 + title −2/−2 → global 18 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I76-A01 | Server fail (−2) + stream fail (−2) on a title subtract 4 from provider Σ | ✅ |
| 2 | I76-A02 | Source badge number matches Σ after negatives (e.g. 22 → 18 with −2 −2 prefixes) | ✅ |

---

## Summary

Per-title reliability totals used `.max(0)` / `.clamp(0, …)` before summing into the provider global score. A title that only recorded fail verdicts (`serverVerdict = −2`, `streamVerdict = −2`) contributed **0** instead of **−4**, so the Source panel could show **22** next to **−2 −2** while Σ never dropped.

**Root fix:** Allow negative per-title nets so they reduce global Σ (and Auto order within the existing ±20 reliability clamp). Ranking already accepts `i32` reliability.

## Related

- [042](042-[fixed]-provider-reliability-not-global.md) — global Σ design
- [stream-providers](../features/sources/stream-providers.md)
- [player](../features/playback/player.md)
