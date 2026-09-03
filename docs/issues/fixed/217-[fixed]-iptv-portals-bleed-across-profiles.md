# 217 — Profile switch leaks prior IPTV portals

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** sync / IPTV (`SyncDomainBridge` / `IptvStore`)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I217-T01 | Wipe device IPTV inventory at start of profile-switch pull (`resetLocalFirst`) before settings/portal cloud fetch | ✅ |
| 2 | I217-T02 | Soft-fail / timeout / continue-early must not re-show prior profile portals; delete-active-profile pulls survivor | ✅ |
| 3 | I217-T03 | Host unit test: boundary wipe clears portals, favorites, last-portal key | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I217-A01 | Profile A has portals → switch to Profile B with different/empty assignments → IPTV never lists A's portals (including sync timeout / Continue) | ✅ |
| 2 | I217-A02 | After wipe, successful pull loads only the active profile's `user_iptv_portals` | ✅ |

---

## Summary

**Incident:** Switching Who's watching profiles showed the **previous** profile's IPTV portals (credentials included). Device `IptvStore` is a **global** SharedPreferences + Keychain cache — not keyed by profile id.

**Root cause:**

1. Profile-switch `resetSyncedLocalToPlatformDefaults` used `clearIptv: false`, so prior portals stayed until a successful cloud pull.
2. Splash soft-fail / 30s timeout / **Continue in background** opened the shell with that leftover local cache ("opening with local cache").
3. Deleting the active profile selected the next id without a fail-closed IPTV wipe + pull.

**Fix:** Fail-closed wipe (`wipeLocalIptvInventoryForProfileBoundary`) at the start of `pullAndMergeAll(resetLocalFirst: true)`; lean reset also clears IPTV; active-profile delete re-pulls; splash copy no longer implies prior IPTV stays.

**Related:** [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) (empty push must not wipe **cloud** — wipe stays `scheduleSync: false`) · [RFC-036](../rfc/036-[open]-accounts-iptv-profile-settings.md) R36-A27
