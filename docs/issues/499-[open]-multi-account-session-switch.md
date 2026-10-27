# 499 — Multi-account session switch

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Account · Sync · Settings  
**Reported:** 2026-10-26 (product: switch Forja cloud accounts on one device without losing other sessions)

## Status at a glance

| | |
|--|--|
| **Progress** | **8 / 8** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Only one GoTrue session is stored (`sb-{host}-auth-token`). Signing into another account replaces the previous session. Users cannot keep multiple Forja cloud accounts on one device and switch between them. Local data is already namespaced by `accountId:profileId`, but auth is single-slot.

## Root cause (hypothesis until verified in code)

- [`ForjaSecureLocalStorage`](../../apps/forja/lib/shared/supabase/forja_secure_local_storage.dart) persists one session blob.
- [`SyncService.signOut`](../../apps/forja/lib/shared/sync/api/sync_service.dart) / login paths have no account vault.
- [`DesktopStartupGate`](../../apps/forja/lib/app/desktop_startup_gate.dart) treats any `signedOut` as return-to-account (would bounce mid-switch without a suppress flag).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I499-T01 | `AccountSessionVault` in secure store (cap, CRUD, active pointer) | ✅ |
| 2 | I499-T02 | `SyncService`: upsert on login/refresh; `switchAccount` / remove / signOut this|all; switch-in-progress flag | ✅ |
| 3 | I499-T03 | Startup gate: ignore `signedOut` during switch; cold-start vault restore | ✅ |
| 4 | I499-T04 | Settings Account panel: list / Add / Switch / Remove / Sign out all | ✅ |
| 5 | I499-T05 | Unit tests: vault rotate, switch no wipe, gate suppress, add-cancel restore | ✅ |
| 6 | I499-T06 | Changelog user-facing Add bullet | ✅ |
| 7 | I499-T07 | Offline downloads path + task index scoped per account/profile; reload on switch | ✅ |
| 8 | I499-T08 | Account chooser: FocusableControl D-pad; X in-row; skipTraversal so row/Add focus first | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I499-A01 | Add account B while on A → switch A↔B → profiles/prefs stay per account | ⬜ |
| 2 | I499-A02 | Sign out A with B in vault → stays on B (no account gate) | ⬜ |
| 3 | I499-A03 | Sign out all → account entry; vault empty | ⬜ |
| 4 | I499-A04 | Downloads completed on A invisible after switch to B / other profile | ⬜ |

## Links

- Plan: multi-account session switch (local agent plan)
- Related: [467](467-[open]-cross-account-simkl-connected-secrets-isolation.md) (Simkl secrets isolation across accounts)
- Keep-alive My List bleed after switch: [502](502-[open]-account-switch-my-list-keep-alive-bleed.md)
- Profile switch (not this): Who’s watching / `selectProfile`
