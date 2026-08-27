# 109 — Android TV / desktop boot: JWT expired after gotrue refresh discard

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/sync/` · `app/bootstrap.dart` · `app/desktop_startup_gate.dart` · gotrue  
**Reported:** 2026-07-25

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 2** acceptance

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I109-T01 | `refreshSession` success = `currentSession` not expired; re-`setSession` when gotrue discards apply | ✅ |
| 2 | I109-T02 | Await boot `ensureFreshAccessToken`; gate pulls with fresh AT; catch profile fetch on startup | ✅ |
| 3 | I109-T03 | Debounce must not skip refresh when access token already expired | ✅ |
| 4 | I109-T04 | Cold start always `refreshSession(force: true)` when session present (do not skip via skew) | ✅ |
| 5 | I109-T05 | `listProfiles` / `pullAccountFeatures` force-refresh + one retry on `PGRST303` / JWT expired | ✅ |
| 6 | I109-T06 | `PGRST303` `JWT issued at future`: retry same token after 1.2s (do not force-refresh); stop dumping it via `[YT]` logger | ✅ |

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

**Follow-up (Settings Profile still failing after T01–T03):** `ensureFreshAccessToken` only refreshes near local expiry. When the device clock / stored `exp` still looks valid but PostgREST rejects `PGRST303`, Settings → Profile kept failing with no refresh attempt. T04 always force-refreshes on cold start; T05 retries profile/feature pulls once after a forced refresh when PostgREST reports JWT expired. Discard re-apply also compares returned vs current access tokens (do not early-return on a different non-expired current).

**Follow-up (boot `JWT issued at future` after T04 force-refresh):** Cold-start `refreshSession(force: true)` mints an AT whose `iat` can be 1–2s ahead of PostgREST. T05 treated every `PGRST303` as expired and force-refreshed again (worse `iat`). T06 retries the **same** token on `issued at future` (`provider_runtime_config`, `profiles`, `profile_settings`, `accounts`). The `[YT]` logger no longer dumps that PostgREST line (supabase_flutter logs it at `fine` before the caller catch). **Not a root fix** — hosted PostgREST iat leeway is still the server-side cause.

**Related:** [085](085-[open]-desktop-involuntary-signout-dumps-login.md) (hard `signedOut`) · [106](106-[open]-desktop-session-profile-chrome-desync.md) (idle chrome) · [RFC-042](../rfc/042-[open]-unified-auth-system.md)
