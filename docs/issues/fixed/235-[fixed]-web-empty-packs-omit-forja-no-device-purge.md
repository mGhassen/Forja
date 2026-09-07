# 235 — Web empty packs omit `forja` → device never purges

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** sync (`sync-domains.ts` · `SyncDomainBridge.importForja`)  
**Reported:** 2026-09-08

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0/1** acceptance smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I235-T01 | Web `compactForja` persists `{ packs: [] }` when forja key is present (do not omit) | ✅ |
| 2 | I235-T02 | Web Forja drafts/saves preserve `onboarded` across pack add/remove | ✅ |
| 3 | I235-T03 | App soft-pull: missing `connectedServices.forja` → `importForja` empty (purge local) | ✅ |
| 4 | I235-T04 | `importForja` debug logs pack count + purge count | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I235-A01 | Web delete all packs on Live → app restart soft-pull purges Installed packs (no Update prompt) | ⬜ |

---

## Summary

**Symptom:** Profile settings on web showed **No packs on this profile yet**, but the desktop app still listed installed packs and offered **Update all**. Nav soft-pull did apply (`visibleIds=[]`); packs did not.

**Root cause:**

1. Web `compactForja` returned `undefined` when `packs` was empty and `onboarded` was absent/dropped — so the DB row lost `connectedServices.forja` entirely.
2. Forja UI drafts saved `{ packs }` only and dropped `onboarded`, which made (1) fire after clearing the last pack.
3. App `_applyLeanPayload` only called `importForja` when `forja is Map` — omission skipped purge; local disk packs + update prompt stayed.

**Fix:** Persist empty `packs: []` on web; preserve `onboarded`; treat omitted cloud `forja` as empty membership and purge on pull.
