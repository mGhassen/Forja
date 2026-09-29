# 389 — Android DNS hang blocks Home rails

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Network · Android TV · Home catalog  
**Reported:** 2026-09-28

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I389-T01 | Dart `PackHttp` races system DNS with DoH, caches the answer, joins in-flight lookups, and skips system DNS for 2 minutes after a timeout | ✅ |
| 2 | I389-T02 | Rust `utils::dns` uses the same race, cache, and skip | ✅ |
| 3 | I389-T03 | Unit tests: DoH does not wait on a hung system lookup; system addresses still win; empty DoH still waits for LAN names | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I389-A01 | Android TV emulator: change a Home category — rails and posters fill without a multi-second blank wait | ⬜ |

---

## Summary

On the Android TV emulator, Private DNS is strict (`private_dns_mode=hostname`, `dns.google`). `netd` logs `doh::ffi: timeout: deadline has elapsed`. The emulator DNS `10.0.2.3:53` does not answer either. `ping 8.8.8.8` works. `ping tmdb.forjahq.xyz` returns `unknown host` after about 5 seconds.

Issue 298 capped that hang at 5 seconds and only then tried Cloudflare DoH, on every new connection, with no memory. A category change starts a fresh client per rail, so every rail and every poster paid the 5 seconds again. Rails that fetch twice sat around 11 seconds. The hub stayed blank for that wait.

Lookup now runs system DNS and DoH together. The first non-empty answer is used and reused for 60 seconds. Same-host lookups that are already running share that probe. After a system-DNS timeout, further probes skip system DNS unless DoH has no answer (LAN names). The skip used to last 2 minutes and then the hung lookup started again — [393](393-[fixed]-android-tv-dns-skip-expires.md).

---

## Related

- [298](298-[fixed]-android-tv-hotspot-dns-unreachable.md) — earlier sequential fallback
- [393](393-[fixed]-android-tv-dns-skip-expires.md) — 2-minute skip re-armed the timeout
