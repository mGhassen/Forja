# 481 — Android TV LAN Discover finds no desktop

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → LAN · mDNS  
**Reported:** 2026-10-25 (manual — desktop LAN on, TV Discover empty)

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Settings → LAN → **Discover on Wi‑Fi** on Android TV returns empty (“No desktop found…”) while the same desktop is announcing and discoverable from other clients / manual IP works.

## Root cause

1. Android filters Wi‑Fi multicast unless `CHANGE_WIFI_MULTICAST_STATE` + a held `WifiManager.MulticastLock`. Manifest lacked the permission; no lock around browse (`MainActivity` / `LanDiscoveryService`).
2. `crates/lan/src/mdns.rs` `browse_forja_servers` treated `recv_timeout` `Err` as “stop browse”, so the first quiet 200ms aborted the whole window instead of waiting the full timeout.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I481-T01 | Manifest `ACCESS_WIFI_STATE` + `CHANGE_WIFI_MULTICAST_STATE`; MethodChannel MulticastLock acquire/release | ✅ |
| 2 | I481-T02 | Hold MulticastLock around `LanDiscoveryService.discover` (and paired rediscover via that path) | ✅ |
| 3 | I481-T03 | mDNS browse: keep polling until deadline on recv timeout (do not `break`) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I481-A01 | Real Android TV + desktop on same Wi‑Fi: Discover lists the desktop within ~3s | ⬜ |
| 2 | I481-A02 | Manual IP:port pair still works; Discover no longer required | ⬜ |

## Links

- [RFC-022 — LAN server/client](../../rfc/022-[open]-lan-server-client.md)
- [027 — LAN manual QA](../027-[draft]-lan-server-client-manual-qa.md)
