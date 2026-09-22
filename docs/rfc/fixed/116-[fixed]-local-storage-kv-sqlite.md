# RFC-116: Local storage — little KV + rusqlite

**Status:** fixed  
**Depends on:** [RFC-082](../082-[open]-account-profile-local-data-scope.md), [RFC-109](../109-[open]-forja-pack-product-host.md)  
**Area:** engine / IPTV / local storage

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** components · **12 / 12** acceptance |
| **Current slice** | Path-scoped KV + rusqlite IPTV catalog + alive/channel-scan shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R116-C01 | Local storage law: KV / SQLite / files / secure / host prefs| ✅ |
| 2 | R116-C02 | Path-scoped `forja_engine_store.json` per identity| ✅ |
| 3 | R116-C03 | Identity-scoped IPTV portal inventory + vault passwords (no wipe-only)| ✅ |
| 4 | R116-C04 | rusqlite `catalog.sqlite` — shelves / categories / streams + page FFI| ✅ |
| 5 | R116-C05 | Alive + channel-scan off SharedPreferences into SQLite; Settings clear aligned| ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R116-A01 | Engine KV opens under `accounts/{a}/profiles/{p}/forja_engine_store.json`; rebind on profile switch| ✅ |
| 2 | R116-A02 | One-time migrate legacy support-root `forja_engine_store.json` into guest (or first active) identity| ✅ |
| 3 | R116-A03 | PortalStore prefs keys + IPTV password SecureSettings key are identity-scoped; bare keys migrate once| ✅ |
| 4 | R116-A04 | EngineVault IPTV inventory keys are identity-scoped| ✅ |
| 5 | R116-A05 | `catalog.sqlite` WAL under same identity path; open/rebind with LocalDataScope| ✅ |
| 6 | R116-A06 | `iptv_catalog_replace_shelf` + `iptv_catalog_page` match pack `catalog_page` JSON shape| ✅ |
| 7 | R116-A07 | Host `PortalCatalogPage` pages via Rust SQL — does not load full `streams[]` into Dart for browse| ✅ |
| 8 | R116-A08 | Settings → IPTV portal cache clears SQLite shelves (+ alive / channel-scan) for active identity only| ✅ |
| 9 | R116-A09 | Alive id sets stored in SQLite (not SharedPreferences JSON blobs)| ✅ |
| 10 | R116-A10 | Channel-scan hits stored in SQLite (not SharedPreferences)| ✅ |
| 11 | R116-A11 | Rust unit tests for page/filter + Dart parity on `filterSort` / page shape| ✅ |
| 12 | R116-A12 | Feature doc cache-data + changelog bullet for IPTV browse| ✅ |

---

## Summary

Two durable engines only:

| Layer | Tech | Owns |
|-------|------|------|
| Little KV | `crates/storage` JSON file | Settings, capped watch history, provider scores |
| Relational | rusqlite `catalog.sqlite` | IPTV categories + streams, alive sets, channel-scan |
| Files | Disk trees | Pack JS, torrent pieces, update installers |
| Secure | Keychain / secure store | Passwords, tokens, vault strings |
| Host prefs | SharedPreferences | Tiny UI flags only |

IPTV `catalog_page` must page in Rust (`LIMIT`/`OFFSET`) so Flutter never holds a multi-MB shelf for browse. Portal passwords stay in SecureSettings. Channel-scan hit rows may still embed stream URLs in the local DB.

### Related

- [RFC-082](../082-[open]-account-profile-local-data-scope.md)
- [Cache & data](../../features/settings/cache-data.md)
