# 516 — Android TV LAN presence poll freezes UI while paired

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Android TV · shell nav · LAN client  
**Reported:** 2026-10-29 (released ATV — freeze every ~few seconds while browsing; worse when desktop LAN active)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I516-T01 | Nav rail 5s LAN poll only on desktop server (`canRunServer`); clients refresh once + on pair/clear events | ✅ |
| 2 | I516-T02 | Turning LAN addon off clears client pairing (+ revoke desktop paired devices) via `stopAndClearPairing` | ✅ |
| 3 | I516-T03 | Client presence / playback prefer-desktop gate on `isLanServerEnabled` so disabled addon cannot keep probing | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I516-A01 | ATV paired to online desktop: browse Home/settings ≥1 min without clockwork UI freezes | ⬜ |
| 2 | I516-A02 | ATV: turn off LAN addon → pairing cleared (must re-pair); rail LAN mark gone | ⬜ |

---

## Symptom

Released Android TV freezes while moving between screens (not only playback). Worse when LAN is paired and the desktop is active; less when paired but desktop inactive.

## Root cause

`ShellNavRail` ran `Timer.periodic(5s)` → `LanPairingPresence.refresh` on **all** platforms. On ATV/phone clients that path does `/health` + `/status` (and on miss sync `lanBrowseServersJson` ≤3s on the UI isolate). The poll comment was for **desktop** peer learning only.

Turning the LAN addon off stopped the server / cleared the enable flag but **left** client token+host, so pairing stayed “live.”

## Links

- [481](481-[fixed]-android-tv-lan-discover-mdns.md) — ATV Discover mDNS
- [RFC-022](../../rfc/022-[open]-lan-server-client.md)
- [465](465-[fixed]-android-tv-details-image-cache-anr.md) — related ~10s KeyEvent ANR class (image cache; separate)
