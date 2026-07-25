# 109 — Android TV / desktop boot: JWT expired after gotrue refresh discard

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/sync/` · `app/bootstrap.dart` · `app/desktop_startup_gate.dart` · gotrue  
**Reported:** 2026-07-25

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I109-T01 | `refreshSession` success = `currentSession` not expired; re-`setSession` when gotrue discards apply | ✅ |
| 2 | I109-T02 | Await boot `ensureFreshAccessToken`; gate pulls with fresh AT; catch profile fetch on startup | ✅ |
| 3 | I109-T03 | Debounce must not skip refresh when access token already expired | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I109-A01 | Android TV cold start with restored session: no `JWT expired` storm; splash/shell opens on last profile | ⬜ |
| 2 | I109-A02 | Desktop cold start same — no unhandled `SyncProfileFetchException` from startup gate | ⬜ |

---

## Summary

Logs showed `signedIn=true` plus `[YT] Session changed during refresh, discarding stale result` (Logger root prefix — message is from gotrue), then PostgREST `PGRST303 JWT expired` and an unhandled `SyncProfileFetchException` from `DesktopStartupGate._enterPostUpdateDestination`.

**Not a wiped session.** The refresh token / local session remain; the **access JWT** stayed stale.

**Root:** Boot fired `refreshSession` while supabase_flutter’s lazy `recoverSession` also mutated session version. gotrue returns fresh tokens in `AuthResponse` but **does not** `_saveSession` when `_sessionVersion` changed mid-flight. Forja treated `response.session != null` as success, then called `accounts` / `profiles` with the still-expired AT. Debounce could also return “ok” without refreshing an already-expired AT.

**Related:** [085](085-[open]-desktop-involuntary-signout-dumps-login.md) (hard `signedOut`) · [106](106-[open]-desktop-session-profile-chrome-desync.md) (idle chrome) · [RFC-042](../rfc/042-[open]-unified-auth-system.md)
