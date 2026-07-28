# 118 — Thin local IPTV cache shrinks cloud portal assignments

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** `sync_domain_bridge.dart` · `sync_service.dart` · `replace_user_iptv_portals` · web `use-user-iptv-portals`  
**Reported:** 2026-07-28

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I118-T01 | Prod recovery — re-assign personal orphans onto Streaming | ✅ |
| 2 | I118-T02 | Refuse IPTV replace when local count is below cloud (unless intentional delete / clear-all) | ✅ |
| 3 | I118-T03 | Web Save refuse catastrophic shrink (thin list over large cloud) | ✅ |
| 4 | I118-T04 | Intentional portal delete uses `pushIptvInventoryAfterDelete` | ✅ |
| 5 | I118-T05 | Prod recovery round 2 — Streaming 453→673 after second wipe (18:01 UTC) | ✅ |
| 6 | I118-T06 | `countUserIptvPortals` fail-closed (`-1` when not ready) + exact head count | ✅ |
| 7 | I118-T07 | Server `replace_user_iptv_portals` refuse shrink unless `p_allow_shrink` | ✅ |
| 8 | I118-T08 | Flutter/web pass `p_allow_shrink` only for intentional delete; refuse partial upsert | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I118-A01 | Streaming shows restored portals after cloud pull; thin local cannot wipe cloud again | ⬜ |
| 2 | I118-A02 | After migration push: thin replace without `p_allow_shrink` raises; intentional delete still works | ⬜ |

---

## Summary

**Incident (morning):** Profile **Streaming** (`ghassen.menaouar@gmail.com`) dropped from hundreds of `user_iptv_portals` to **5** at **2026-07-28 01:28:14 UTC** (single `replace_user_iptv_portals`). Global `iptv_portals` rows survived. **Live** still had 89.

**Incident (evening, round 2):** Same profile wiped again to **453** at **2026-07-28 ~18:01 UTC** (all assignment rows recreated in that hour). Client shrink guard alone was insufficient — `countUserIptvPortals` returned **0** when auth/profile was not ready (fail-open), so a thin local cache could still replace cloud.

**Root cause:** Issue [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) blocked **empty** replace only. A **thin** local cache still called `replace_user_iptv_portals` and deleted the rest. Cloud is master; local is cache. Server RPC had no shrink refuse.

**Recovery (prod):**
1. Morning: re-inserted **608** personal orphans → **613** on Streaming.
2. Evening: re-inserted **220** personal orphans → **673** on Streaming. Live unchanged (89).

**Symptom fix:** Client count refuse + delete path flag (T02–T04).

**Root fix:** Server refuses shrink unless `p_allow_shrink`; client count fail-closed + exact count; partial upsert never replace (T06–T08). Migration must be **pushed to prod** before A02.

**Related:** [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) (empty wipe). Lazy IPTV pull when `iptv` nav hidden (B101-S130) clears **local** only (`scheduleSync: false`) — must not be followed by a thin push.

## Verify

1. Sign in → Streaming → IPTV shows ~673 portals after sync pull  
2. With cloud full, force a thin local cache and trigger sync — cloud count unchanged (server error if replace attempted without shrink)  
3. Delete one portal in UI — cloud drops by one (intentional shrink)
