# 042 — Provider reliability scores are per-title only (no global sum)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/resolver-engine/src/health_store.rs`, `crates/stream/src/source_order.rs`, Settings Source scoring, player badge

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **4 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I42-T01 | Sum per-title totals into a global score per provider id | ✅ |
| 2 | I42-T02 | Feed global reliability into `order_providers` ranking (±clamp) | ✅ |
| 3 | I42-T03 | Settings Source scoring shows live Σ; player badge stays per-title | ✅ |
| 4 | I42-T04 | Rust + Dart tests for cross-title sum + order nudge | ✅ |
| 5 | I42-T05 | Player Sources badge number shows global Σ; ± prefixes stay per-title | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I42-A01 | Two films up on same server → Settings Σ is sum of both title totals | ✅ |
| 2 | I42-A02 | Global reliability changes effective pre-check order within ±2 | ✅ |
| 3 | I42-A03 | Player badge on film B still starts at 0 until B is checked | ✅ |
| 4 | I42-A04 | Player badge number = provider Σ; ±2 prefixes = current title only | ✅ |

---

## Summary

Runtime server/stream verdicts were stored only as `movie:{tmdb}:{provider}` (etc.) and never summed. Settings Score stayed a static domain profile. Providers could not learn reliability across titles.

**Root fix:** `ProviderHealthStore::all_provider_totals` sums title totals by provider; FFI `order_providers` injects that map; ranking uses `domain + clamp(Σ, ±20)` inside the existing ±2 displacement; Settings shows Domain + Σ; player Sources badge number shows Σ with per-title ± prefixes.

## Related

- [stream-providers](../features/sources/stream-providers.md)
- [playback-settings](../features/settings/playback-settings.md)
- [RFC-031](../rfc/031-[open]-source-engine-middleware.md)
