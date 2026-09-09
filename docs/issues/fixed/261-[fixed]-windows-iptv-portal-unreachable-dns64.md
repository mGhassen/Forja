# 261 — Windows IPTV portal unreachable (DNS64 AAAA)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV Xtream/Stalker/M3U portal HTTP · Windows  
**Reported:** 2026-09-09

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I261-T01 | Shared IPTV HTTP client binds outbound sockets to IPv4 | ✅ |
| 2 | I261-T02 | Wire Xtream / Stalker / M3U / stream probe through shared client | ✅ |
| 3 | I261-T03 | Engine bump + changelog + feature tip | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I261-A01 | Windows: same Xtream portal that works on macOS/ATV shows green status + loads Live catalog | ⬜ |

---

## Summary

Same Xtream portal (e.g. `*.dnsabr.com`) worked on Android TV and macOS but Windows painted **Unreachable** / “Could not reach portal” with a red status pill.

**Root cause:** DynDNS / ISP DNS64 synthesizes AAAA under `64:ff9b::/96` (NAT64 prefix). Windows `getaddrinfo` prefers IPv6; without a working NAT64 gateway the connect fails or burns the probe timeout. macOS often requests A records only for the same host, so IPv4 succeeds.

**Root fix:** `crates/iptv/src/http.rs` — `local_address(0.0.0.0)` on portal/stream reqwest clients so login, catalog, and alive probes always use IPv4.

### Related

- [252](fixed/252-[fixed]-iptv-status-checks-false-red.md) — earlier false-red (timeout/auth), separate
- [iptv-xtream](../../features/live/iptv-xtream.md)
