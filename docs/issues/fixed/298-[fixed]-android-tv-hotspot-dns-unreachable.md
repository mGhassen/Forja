# 298 — Android TV / hotspot: catalog + IPTV unreachable (DNS)

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Network · Android TV · hotspot · EngineJS / IPTV / catalog HTTP  
**Reported:** 2026-09-20

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 7 / 7** fix · **0 / 2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I298-T01 | Shared Rust DoH resolver (`utils::dns`) — system DNS timed, then `1.1.1.1` | ✅ |
| 2 | I298-T02 | Wire EngineJS `native_fetch`, stremio HTTP, live-sports HTTP | ✅ |
| 3 | I298-T03 | Wire IPTV portal HTTP (IPv4-only + DoH) + Reddit catalog client | ✅ |
| 4 | I298-T04 | Flutter_js host HTTP via `PackHttp.ioClient` (same DoH path) | ✅ |
| 5 | I298-T05 | Engine bump 1.2.78 + changelog + feature tip | ✅ |
| 7 | I298-T07 | DoH bootstrap: IP literal short-circuit + non-recursive DoH client (no 1.1.1.1 timeout storm) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I298-A01 | Android TV on phone hotspot: Anime / Asian Drama / Home rails load (no `HTTP 0`) | ⬜ |
| 2 | I298-A02 | Same network: IPTV portal reaches Live catalog (no “Could not reach portal”) | ⬜ |

---

## Summary

On Android TV (and the TV emulator) connected through a **phone hotspot**, IP connectivity worked (`ping 8.8.8.8`) but **hostname lookup failed** (`unknown host google.com`). Private DNS was forced to `dns.google` (DoT). Catalog and IPTV then failed with `HTTP 0` / “Could not reach portal”.

Pack install already fell back to Cloudflare DoH (`PackHttp`). Engine / IPTV / flutter_js host HTTP still used system DNS only — they died on the same networks.

**Root fix:** shared `utils::dns::DohFallbackResolver` (system → DoH) on Rust HTTP clients; Dart `PackHttp.ioClient()` for flutter_js; Android `HttpOverrides` attaches the same DoH resolver so Supabase / profile sync / updater resolve too.

---

## Related

- Pack install DoH: changelog 1.5.x · `PackHttp`
- Windows IPTV DNS64 (IPv4-only): [261](261-[fixed]-windows-iptv-portal-unreachable-dns64.md) · [269](../269-[open]-windows-iptv-portal-af-inet-dns64.md)
