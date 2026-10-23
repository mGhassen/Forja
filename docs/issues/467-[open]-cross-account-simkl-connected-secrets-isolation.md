# 467 — Cross-account Simkl / connected secrets isolation

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · account · connected services / My List  
**Reported:** 2026-10-23 (manual ATV: logout A → login B still shows A’s My List + Simkl)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Android TV, sign out of Forja account A, sign into account B:

1. **My List** still shows titles from A (Simkl-fed merge).
2. **Settings → Connected services → Simkl** still shows connected as A’s Simkl.

Same device, two Forja accounts — B must never see A’s tracker link or list merge.

## Root cause

Verified in code:

- `LocalDataScope` already isolates prefs as `base@accountId:profileId` (My List bookmarks use this).
- Simkl / MDBList / pack secrets used **device-global** secure keys (`simkl_access_token`, `mdblist_api_key`, `pack_secret_v1_*`).
- Forja sign-out rebinds to guest and does **not** (and must not) delete those keys — leftover global token made B’s session read A’s Simkl.
- My List pack merges Simkl when `SimklService.isLoggedIn()`.

**Policy:** isolate per identity. Do **not** wipe on logout. Each account/profile keeps its own device cache.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I467-T01 | `LocalDataScope.migrateSecureBareIfNeeded` (skip guest; bare → active scope) | ✅ |
| 2 | I467-T02 | Scope Simkl secure keys + clear in-memory caches on scope change (no disk wipe) | ✅ |
| 3 | I467-T03 | Scope MDBList API key + cache reset on scope change | ✅ |
| 4 | I467-T04 | Scope pack secrets / pack settings prefs / pack connected-auth label+ids | ✅ |
| 5 | I467-T05 | Settings export/import + Connected-services providers follow active scope | ✅ |
| 6 | I467-T06 | Unit tests: A write → B empty → A still present; guest rebind does not delete A | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I467-A01 | ATV: Simkl on A → sign out → sign in B → Simkl disconnected, My List has no A bleed | ⬜ |
| 2 | I467-A02 | Sign back into A → Simkl still connected, My List restored from A’s cache | ⬜ |
| 3 | I467-A03 | Profile switch A/p1 → A/p2 does not share Simkl token | ⬜ |

## Out of scope (this issue)

- I85 `clearAccountBoundLocalState` IPTV/prefs wipe on sign-out — separate policy; do not extend wipe to trackers.
- Debrid / Jackett device-global keys — same leak class; follow-up if needed.

## Links

- [RFC-082](../rfc/082-[open]-account-profile-local-data-scope.md)
- [085](085-[open]-desktop-involuntary-signout-dumps-login.md) — wipe path (IPTV/prefs only)
- [206](fixed/206-[fixed]-simkl-smart-sync-delta-cw-cap.md) — SimklService.logout clears activity (not Forja sign-out)
