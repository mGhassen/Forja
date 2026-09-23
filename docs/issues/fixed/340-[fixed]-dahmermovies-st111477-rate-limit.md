# 340 — DahmerMovies empty Sources (st.111477 Cloudflare 429)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/dahmermovies.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I340-T01 | Probe live `st.111477.xyz` addon — streams OK until CF 1015/429; recovers after ~8s | ✅ |
| 2 | I340-T02 | Retry addon fetch on 429/1015 with 7.2s backoff (same as index scrape) | ✅ |
| 3 | I340-T03 | Providers pack 1.6.11 + changelog + host string test | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I340-A01 | After a burst that trips 429, a single extract with backoff returns ≥1 stream for Inception (`tt1375666`) | ✅ |
| 2 | I340-A02 | App: Sources → DahmerMovies lists streams after reopen / quick title switch (manual) | ⬜ |

---

## Summary

DahmerMovies uses the PlayTorrio Stremio-addon path (`st.111477.xyz/config/…/stream/…`). That endpoint returns real `workers.dev` play URLs when healthy, but Cloudflare **error 1015 / HTTP 429** after a few requests from the same IP. The plugin treated any non-200 as empty and returned **0 streams** with no wait.

### Fix

- On 429 / 5xx / body matching CF 1015, wait **7200 ms** and retry (up to 4 times) — same timing as `crates/proxy` index scrape
- Still uses the addon JSON path only (no `a.111477` HTML scrape)
- Providers pack **1.6.11**

### Related

- [013](fixed/013-[fixed]-site111477-captcha-still-dart.md) — index scrape CF backoff (Dart/Rust)
- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md) — EngineJS Sources
- [stream providers](../../features/sources/stream-providers.md)
