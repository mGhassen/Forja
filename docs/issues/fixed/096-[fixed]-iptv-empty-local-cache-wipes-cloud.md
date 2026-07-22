# 096 — Empty local IPTV cache wiped cloud portal assignments

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** `sync_domain_bridge.dart` · `sync_service.dart` · `IptvStore` · web `use-user-iptv-portals`  
**Reported:** 2026-07-22

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5/5** fix · **0/1** acceptance smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I96-T01 | Refuse empty IPTV cloud replace from cache / profile switch | ✅ |
| 2 | I96-T02 | Pull cloud → local without scheduling a push | ✅ |
| 3 | I96-T03 | Local wipe / seed uses `scheduleSync: false` | ✅ |
| 4 | I96-T04 | Intentional clear-all uses `pushEmptyIptvInventory` only | ✅ |
| 5 | I96-T05 | Web Save refuses empty portal list | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I96-A01 | Switch profile with empty local cache — cloud assignments unchanged | ⬜ |

---

## Summary

**Incident:** Profile **Streaming** (`ghassen.menaouar@gmail.com`) lost all `user_iptv_portals` at **2026-07-22 14:36:07 UTC**. Global `iptv_portals` rows survived. Live profile still had 79.

**Root cause:** Flutter treated device `IptvStore` as source of truth. `prepareProfileSwitch` → `pushAllLocal` → `replaceUserIptvPortals([])` **deleted** all cloud assignments when local cache was empty. Cloud is master; local is cache only.

**Symptom fix:** Guards — never push empty IPTV inventory except explicit clear-all; pull does not schedule push; web Save rejects empty list.

**Recovery (prod):** Re-inserted **266** personal orphans (`created_by` = account, `catalog_pool = false`, unassigned) onto Streaming. Left catalog-pool orphans alone.

**Root / product rule:** Cloud assignments win; empty cache must never delete them.

## Verify

1. Sign in → Streaming → IPTV shows restored portals  
2. Clear local store / switch profiles without deleting in UI — cloud count unchanged  
3. Delete all portals in UI — cloud becomes empty (intentional)
