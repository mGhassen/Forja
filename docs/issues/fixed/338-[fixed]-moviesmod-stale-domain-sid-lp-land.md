# 338 — MoviesMod empty Sources (stale domain + SID lp-land)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/moviesmod.js` · `domains.json` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I338-T01 | Point SPECS / domains.json at live `moviesmod.ai.in` (`.army` CF challenge; `.cc` SEO park) | ✅ |
| 2 | I338-T02 | SID bypass: `form#lp-land` → `lp-sN-form` → `sc(cookie)` + `?lp_go=` + `location.replace` | ✅ |
| 3 | I338-T03 | Driveseed: emit Direct Links (`workers.dev`) and path-token Instant CDNs | ✅ |
| 4 | I338-T04 | Providers pack 1.6.10 + feature/changelog docs; share SID fix with UHDMovies | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I338-A01 | curl: `moviesmod.ai.in/?s=Oppenheimer` hits title page; modpro → thenaukriadda SID resolves to `driveseed.org` | ✅ |
| 2 | I338-A02 | curl: driveseed file page Direct Links (`?type=1`) yields `workers.dev` file URL | ✅ |
| 3 | I338-A03 | App: Sources → MoviesMod lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

MoviesMod search used `domains.json` → `moviesmod.army` (Cloudflare managed challenge) with fallback `moviesmod.cc` (unrelated streaming landing page). Live catalog is **`https://moviesmod.ai.in`**.

Download gates moved from `form#landing` / `?go=` to **linkpilot** `form#lp-land` → timer form `lp-sN-form` → JS `sc(name,value)` cookie + `?lp_go=` → `location.replace` to Driveseed. Instant CDN buttons often 500; **Direct Links** still return playable `workers.dev` URLs.

**Root fix:** update domain + SID bypass + Direct Links extraction. Same SID path patched in UHDMovies. Not a workaround.

### Related

- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- [stream providers](../../features/sources/stream-providers.md)
- [335 HDHub4u domain/host churn](335-[fixed]-hdhub4u-stale-base-hubcloud-dad.md)
