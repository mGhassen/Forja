# 433 — Live Sports Portals chip stale after IPTV select

**Priority:** P1  
**Severity:** Medium  
**Status:** fixed  
**Area:** `apps/forja/lib/shared/engine/runtime/actions/portals/` — Portals chip  
**Reported:** 2026-10-14  
**Fixed:** 2026-10-14  

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-T01 | Shared (non-family) `portalsChipSummaryProvider` for all hubs | ✅ |
| 2 | I433-T02 | `setActiveKey` bumps `PortalStore.listRevision` | ✅ |
| 3 | I433-T03 | Chip listens to `listRevision` so Live Sports refreshes after IPTV select | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I433-A01 | IPTV: select portal B → Live Sports top-bar Portals chip shows B | ⬜ |
| 2 | I433-A02 | Live Sports: select portal A → IPTV Portals chip shows A; Live TV search still uses A | ⬜ |

---

## Summary

Changing the active portal on IPTV updated Live TV search but left the Live Sports top-bar **Portals** chip on the previous portal name.

## Root cause

Active portal is vault-global, but `portalsChipSummaryProvider` was a keepAlive family keyed by `tabId`. Select only called `invalidatePortalsChrome` for the current tab, and `setActiveKey` did not bump `listRevision`.

## Fix approach

One shared chip provider (vault active is global). `setActiveKey` notifies `PortalStore.listRevision`; the chip and per-hub inventories listen so every Portals surface refreshes.

**Non-goals:** reloading the Live Sports match schedule on portal select (schedule is not portal-scoped; only Live TV matching is).
