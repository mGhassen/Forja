# 308 — IPTV pack Add/Import never syncs portals to web

**Priority:** P0  
**Severity:** Critical  
**Status:** fixed  
**Area:** IPTV portals · vault → PortalStore → `user_iptv_portals` · web Addons → IPTV  
**Reported:** 2026-09-21

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I308-T01 | After pack add/edit/import: mirror vault → `PortalStore.save` + `scheduleIptvSyncPush` | ✅ |
| 2 | I308-T02 | Heal: panel prepare / soft path pushes vault-only inventory when store is empty | ✅ |
| 3 | I308-T03 | Favorite toggle mirrors + schedules IPTV sync | ✅ |
| 4 | I308-T04 | Changelog + issue acceptance | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I308-A01 | Add portal in app → web Profile → Addons → IPTV lists it for the same profile within soft-pull / few seconds | ⬜ |
| 2 | I308-A02 | Existing vault-only portal (never pushed) appears on web after opening Portals or soft sync | ⬜ |

---

## Summary

**Symptom:** App IPTV shows a live portal; web **Addons → IPTV** shows **0 portals** for the same profile.

**Root:** Pack `addPortal` / `importPortal` / `editPortal` write **engine vault only**. Cloud push reads **PortalStore**. Delete already mirrored vault → store → push; add never did — so `user_iptv_portals` stayed empty.

**Fix:** `PortalVaultInventory.mirrorVaultToStoreAndScheduleSync` after pack inventory mutations; heal when store is empty on Portals panel prepare and soft-pull (IPTV tab visible).
