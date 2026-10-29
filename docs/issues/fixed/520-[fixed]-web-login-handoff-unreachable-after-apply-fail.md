# 520 — Web login handoff: “Could not reach the Forja app” after apply fail

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Account · Web login · desktop/mobile loopback handoff  
**Reported:** 2026-10-29 (Android emulator phone flavor, `dev.forjahq.xyz` desktop handoff UI)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Portal shows Desktop handoff “You are already signed in” then the red error **Could not reach the Forja app** after tapping **Return to Forja**. App may still be waiting on Web login.

## Root cause

Verified on emulator logs:

1. Portal `fetch` hit the app loopback (`[DesktopBrowserAuth] GET /callback`).
2. `signInWithBrowserTokens` → `setSession` failed once with `AuthRetryableFetchException` / `Failed host lookup` for the Supabase host (transient DNS).
3. `DesktopBrowserAuth` treated apply failure as terminal: `finish(failure)` closed the loopback server.
4. Later **Return to Forja** could not reach `127.0.0.1` → portal `unreachable` copy.

`apps/forja/lib/shared/sync/auth/desktop_browser_auth.dart` (apply `catch` + `finish`) · `sync_service.dart` `signInWithBrowserTokens` (no network retry).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I520-T01 | Keep loopback listening after `onTokens` failure so Return to Forja can retry; guard overlapping applies | ✅ |
| 2 | I520-T02 | Retry `setSession` on `isRetryableAuthNetworkError` (DNS / socket) before failing the handoff | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I520-A01 | After a transient apply failure, a second Return to Forja reaches the same loopback and can succeed | ⬜ |
| 2 | I520-A02 | Unit: `desktop_browser_auth_test` keeps listening after first `onTokens` throw | ✅ |

## Links

- Related: [519](519-[fixed]-android-session-not-durable-cold-start.md) (Android session vault)
- Auth path: `DesktopBrowserAuth` · portal `mintAndHandoffToDesktop`
