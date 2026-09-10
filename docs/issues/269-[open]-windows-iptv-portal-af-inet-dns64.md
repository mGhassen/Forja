# 269 — Windows IPTV portal unreachable: AF_INET DNS (DNS64 residual)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV Xtream/Stalker/M3U portal HTTP · Windows  
**Reported:** 2026-09-10

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 1** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I269-T01 | Custom reqwest DNS resolver: AF_INET `getaddrinfo` (A records) | ✅ |
| 2 | I269-T02 | Keep IPv4 `local_address` + engine bump | ✅ |
| 3 | I269-T03 | Changelog + feature tip + link from 261 | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I269-A01 | Windows: share-import / open same DynDNS portal that works on Mac/ATV loads Live (no “Could not reach portal”) | ⬜ |

---

## Summary

[261](fixed/261-[fixed]-windows-iptv-portal-unreachable-dns64.md) bound sockets to IPv4 via `local_address(0.0.0.0)`. Hyper then **filters** AF_UNSPEC DNS results to IPv4. When Windows DNS64 returns **AAAA-only** (synthesized `64:ff9b::/96`), that filter yields an **empty** address list → still “Could not reach portal” after share-code import.

**Root fix:** `crates/iptv/src/http.rs` — custom `Resolve` that calls `getaddrinfo` with `AF_INET` so real A records are used; keep IPv4 local bind.

### Related

- [261](fixed/261-[fixed]-windows-iptv-portal-unreachable-dns64.md) — incomplete first slice
- [iptv-xtream](../../features/live/iptv-xtream.md)
