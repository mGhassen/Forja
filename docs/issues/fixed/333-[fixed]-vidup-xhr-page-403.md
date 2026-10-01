# 333 — VidUp empty Sources (X-Requested-With on page GET)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/vidup.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I333-T01 | Probe live `vidup.to` — confirm page GET with `X-Requested-With: XMLHttpRequest` returns nginx 403 | ✅ |
| 2 | I333-T02 | Split page vs API headers; keep XHR header only on servers/stream POSTs | ✅ |
| 3 | I333-T03 | Providers pack 1.6.6 + feature/changelog docs + host regression assert | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I333-A01 | Live probe: TMDB `1399` S1E1 and movie `550` decrypt to HLS `url` with page headers sans XHR | ✅ |
| 2 | I333-A02 | App: Sources → VidUp lists streams (manual) | ⬜ |

---

## Summary

VidUp Forja used one header bag for the title page **and** the encrypted servers/stream POSTs. That bag included `X-Requested-With: XMLHttpRequest`. Live `vidup.to` returns **nginx 403** on the HTML page when that header is present, so token extraction failed and Sources showed **0 streams**. The same header is still required (with optional empty `X-CSRF-Token`) on the POST steps.

### Fix

- Page GET: `User-Agent` + `Referer` only (same shape as VidFast)
- API POSTs: keep `X-Requested-With` + CSRF token from `enc-vidup`
- Prefer decrypted `stream.url`; Providers pack **1.6.6**

### Related

- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md) — EncDec VidUp plugin
- [stream providers](../../features/sources/stream-providers.md)
