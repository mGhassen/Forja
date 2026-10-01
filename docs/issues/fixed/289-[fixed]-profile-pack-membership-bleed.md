# 289 — New profile inherits other profile packs

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Sync · packs · profiles · local checkout

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** fix · **0 / 4** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I289-T01 | Create / seed profile hard-empties pack index + cloud forja wipe | ✅ |
| 2 | I289-T02 | Empty cloud lean drops local checkout membership (cloud SoT) | ✅ |
| 3 | I289-T03 | Scope-stamp pack install writes; abort if profile switched | ✅ |
| 4 | I289-T04 | Stop bare `engine_js_packs_v2` lazy-copy into new profiles | ✅ |
| 5 | I289-T05 | Tests: empty lean / same-slot keep / scope abort / prefs isolation | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I289-A01 | Create profile B while A has local checkouts → B Settings packs empty, cloud packs empty | ⬜ |
| 2 | I289-A02 | Soft-pull empty on B does not revive local checkout paths on B; A unchanged | ⬜ |
| 3 | I289-A03 | Reload/install started on A, switch to B mid-flight → B pack index stays empty | ⬜ |
| 4 | I289-A04 | Cloud has remote same-slot URL on A → local checkout path may satisfy A only | ⬜ |

---

## Summary

**Symptom:** Creating or opening a new profile shows packs already installed (including local `forja-packs` checkout paths) without choosing them.

**Root cause:**

1. `seedNewProfileDefaults` resets settings but explicitly does not clear the pack index.
2. Soft-pull `applyLeanManifestUrls` keeps readable local checkout paths even when cloud `packs[]` is empty — membership bypasses profile SoT.
3. `createProfile` → `selectProfile(newId)` while an install/reload is in flight writes `_savePacks` into the new profile’s scoped prefs key.
4. Bare unscoped `engine_js_packs_v2` lazy-migrates into the first profile that reads it.

**After:** Cloud lean membership is SoT per profile. New profiles start with an empty pack index (`clearPackMembershipForActiveProfile` + `allowEmptyForjaWipe`). Local checkout is only an install source — empty cloud drops those rows (same-slot remote still keeps a readable local path). Install writes abort when `LocalDataScope.generation` changes. Bare prefs keys are dropped, never copied into a new profile.

**Related:** [217](217-[fixed]-iptv-portals-bleed-across-profiles.md) · [259](../259-[open]-cloud-pack-auto-install-before-profile-splash.md)

## Verify

1. Profile A with local checkouts installed → create profile B → open B → Settings → Forja Packs empty; no hub tabs until packs onboard.
2. Soft-pull on B with empty cloud → still empty; A still has its packs.
3. Start Reload all on A → immediately switch to B → B stays empty.
