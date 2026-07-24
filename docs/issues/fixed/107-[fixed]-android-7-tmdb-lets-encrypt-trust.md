# 107 — Android ≤7.0 TMDB posters fail (Let's Encrypt trust)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TLS · `CachedNetworkImage` · TMDB `image.tmdb.org` / `media.themoviedb.org` · Home · Asian Drama  
**Reported:** 2026-07-25 (Toshiba Android 7 TV)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I107-T01 | Bundle ISRG Root X1/X2 in `res/raw` + `network_security_config` trust-anchors (keep `system`) | ✅ |
| 2 | I107-T02 | `installLegacyAndroidTlsTrust()` — Android `HttpOverrides` adds ISRG roots before any image fetch | ✅ |
| 3 | I107-T03 | Unit test PEM constants non-empty / well-formed | ✅ |
| 4 | I107-T04 | Asian Drama: rewrite KissKH `media.themoviedb.org` covers → `image.tmdb.org` (Rust + Dart) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I107-A01 | Android 7.0 TV (or API 24 emulator): Home posters load from `image.tmdb.org` (no `Trust anchor` in logcat) | ⬜ |
| 2 | I107-A02 | Same device: Asian Drama hub posters/hero load (KissKH covers that use TMDB media CDN) | ⬜ |

---

## Summary

On **Android 7.0 and older**, the system CA store does not include **ISRG Root X1** (shipped from Android 7.1.1). After Let's Encrypt dropped the DST Root CA X3 cross-sign (2024), HTTPS to LE hosts fails with `CertPathValidatorException: Trust anchor for certification path not found`.

**Split stack:**

| Fetch | Stack | Trust | On Android 7.0 |
|-------|-------|-------|----------------|
| TMDB / KissKH catalog JSON | Rust `reqwest` + rustls | Mozilla/webpki roots | OK |
| Posters / backdrops / KissKH covers | Flutter `CachedNetworkImage` → Dart `HttpClient` | **Platform** trust store on Android | Fail |

**Surfaces:** Home (`image.tmdb.org`) and Asian Drama (KissKH thumbnails often `media.themoviedb.org` → 301 to `image.tmdb.org` — same LE chain). Hubs look empty: dark cards + faint titles while JSON still returns.

**Symptom / host fix:** embed ISRG Root X1 + X2 in the app trust path (`network_security_config` + Dart `HttpOverrides`). KissKH covers also rewrite to `image.tmdb.org` so they share Home’s image path.

**Not a workaround:** roots are the correct trust anchors for LE; no user cost.

**Verify:** `adb logcat` while opening Home + Asian Drama — no SSL handshake errors for `image.tmdb.org` / `media.themoviedb.org`; posters visible.
