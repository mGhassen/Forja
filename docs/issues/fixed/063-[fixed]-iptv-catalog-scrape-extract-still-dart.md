# 063 — IPTV catalog scrape extract still Dart

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** `crates/iptv` · `apps/forja/lib/features/iptv/data/iptv_network.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I63-T01 | Port portal credential extraction (`_extractPortals` / finalize / URL clean) to Rust | ✅ |
| 2 | I63-T02 | Port Reddit post + RSS parse + base64/paste deep-link follow into Rust `scrape_page` | ✅ |
| 3 | I63-T03 | Thin Dart `IptvScraper` to call `iptv_reddit_catalog_json` `scrape_page` and map portals | ✅ |
| 4 | I63-T04 | Rust unit + Dart parity tests for extract + scrape_page contract | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I63-A01 | Reddit Scrape / Get More returns portals via Rust-prepared JSON (no Dart regex extract on hot path) | ✅ |
| 2 | I63-A02 | Cursor pagination (`reddit:<sub>:<token>`) still advances across catalog subs | ✅ |
| 3 | I63-A03 | Paste / base64 deep links still contribute portals when present in OAuth posts | ✅ |

---

## Summary

P2-94 moved IPTV HTTP (Reddit OAuth, RSS fetch, paste fetch/decrypt) into `crates/iptv`, but **portal extraction** and **deep-link orchestration** stayed in Dart `IptvScraper` (`iptv_network.dart`). That violated [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) Pattern B (fetch+parse in Rust) and R7.

**Root cause (before fix):** Incomplete engine port — Rust returned raw listing/paste bodies; Dart still parsed posts, extracted Host/User/Pass, and followed paste links.

**Fix (shipped):**

- `crates/iptv/src/portal_extract.rs` — credential extraction
- `crates/iptv/src/reddit_catalog.rs` — `scrape_page` + `extract_portals` actions (fetch + parse + deep links)
- Dart `IptvScraper` — thin wrapper mapping `{ portals, next_after }`

**Verify:**

```bash
cd crates && cargo test -p iptv --lib
cd packages/rust && flutter test test/parity/live_matches_iptv_test.dart
cd apps/forja && flutter test test/iptv_catalog_cursor_test.dart
```

## Related

- [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) — cursor format (preserved)
- [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) D8 / R5 / R7
- Feature: [IPTV Xtream](../features/live/iptv-xtream.md)
