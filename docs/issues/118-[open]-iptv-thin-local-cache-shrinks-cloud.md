# 118 — Thin local IPTV cache shrinks cloud portal assignments

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** `sync_domain_bridge.dart` · `sync_service.dart` · web `use-user-iptv-portals`  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I118-T01 | Prod recovery — re-assign personal orphans onto Streaming | ✅ |
| 2 | I118-T02 | Refuse IPTV replace when local count is below cloud (unless intentional delete / clear-all) | ✅ |
| 3 | I118-T03 | Web Save refuse catastrophic shrink (thin list over large cloud) | ✅ |
| 4 | I118-T04 | Intentional portal delete uses `pushIptvInventoryAfterDelete` | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I118-A01 | Streaming shows restored portals after cloud pull; thin local cannot wipe cloud again | ⬜ |

---

## Summary

**Incident:** Profile **Streaming** (`ghassen.menaouar@gmail.com`) dropped from hundreds of `user_iptv_portals` to **5** at **2026-07-28 01:28:14 UTC** (single `replace_user_iptv_portals`). Global `iptv_portals` rows survived. **Live** still had 89.

**Root cause:** Issue [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) blocked **empty** replace only. A **thin** local cache (e.g. 5 portals after wipe / incomplete pull / Deal) still called `replace_user_iptv_portals` and deleted the rest. Cloud is master; local is cache.

**Recovery (prod):** Re-inserted **608** personal orphans (`created_by` = account, `catalog_pool = false`, unassigned) onto Streaming → **613** total (kept the 5). Left catalog-pool orphans alone. Live unchanged (89).

**Symptom fix:** Count cloud assignments before replace; refuse shrink unless intentional delete / clear-all. Web Save uses the same catastrophic-shrink guard.

**Related:** [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) (empty wipe). Lazy IPTV pull when `iptv` nav hidden (B101-S130) clears **local** only (`scheduleSync: false`) — must not be followed by a thin push.

## Verify

1. Sign in → Streaming → IPTV shows ~613 portals after sync pull  
2. With cloud full, force a thin local cache and trigger sync — cloud count unchanged  
3. Delete one portal in UI — cloud drops by one (intentional shrink)
