# 354 — IPTV Movies / Series shelf fails on portal HTTP 503 (no retry)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · Xtream catalog · Movies / Series shelf

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I354-T01 | Xtream `http_get`: retry HTTP ≥500 + transport blips (Stalker parity: 3 attempts, 300/800ms backoff) | ✅ |
| 2 | I354-T02 | Unit tests for `is_retriable` + engine bump | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I354-A01 | App: cold open IPTV **Movies** on a portal that briefly 503s — shelf loads without manual Reload | ⬜ |
| 2 | I354-A02 | App: cold open **Series** same portal — shelf loads (or keeps loading) instead of instant “Could not load catalog” | ⬜ |

---

## Summary

**Symptom:** First tap of IPTV **Movies** / **Series** showed “Could not load catalog” / empty. **Reload** then painted the list.

**Root cause:** Cold shelves call Rust Xtream `catalog` (`get_vod_streams` / `get_series`). One portal `HTTP 503` failed the shelf with no retry. Stalker already retried gateway/transport errors; Xtream did not. Host logged `[PortalCatalogPage] catalog error: HTTP 503`.

**Fix:** Xtream `http_get` retries transient failures (HTTP ≥500, timeouts, connection/DNS/TLS) up to 3 attempts with short backoff — same policy as Stalker.

### Related

- [290](../290-[open]-iptv-catalog-page-host-shelf.md) — host `catalog_page` shelf  
- [094](094-[fixed]-iptv-catalog-refetch-every-launch.md) — shelf disk warm path  
