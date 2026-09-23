# 336 — 1Shows empty Sources (origin + AES key rotate)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/1shows.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I336-T01 | Probe live site — confirm `.org` Origin gets CF 403; `.bz` returns download-token | ✅ |
| 2 | I336-T02 | Re-derive AES-256 key from current `makimaDL.wasm`; update origin + key in `1shows.js` | ✅ |
| 3 | I336-T03 | Providers pack 1.6.9 + feature/changelog docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I336-A01 | curl: Origin `https://www.1shows.bz` + new key decrypts `/download/movie/27205` to ≥1 source | ✅ |
| 2 | I336-A02 | App: Sources → 1Shows lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

1Shows moved the public site to **`www.1shows.bz`**. API `api.viduki.net` still works, but Cloudflare challenges requests that send the old **`www.1shows.org` Origin** — `download-token` returns 403 challenge HTML, so extract returns **0 streams**.

Separately, `makimaDL.wasm` rotated (generated 2026-09-22). The AES-256 key is no longer the raw StaticArray; it is derived from the wasm tables. The old hardcoded key fails GCM auth even when the token call succeeds.

### Fix

- Origin → `https://www.1shows.bz`
- AES key → derived value from current `makimaDL.wasm`
- Prefer hex-decoded download token as GCM AAD (matches the site)
- Providers pack **1.6.9**

### Related

- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md) — EngineJS Sources plugins
- [stream providers](../../features/sources/stream-providers.md)
