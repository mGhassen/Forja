# 525 — Phone Web login: first handoff fails on Auth DNS flake

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Account · phone Web login · desktop handoff loopback  
**Reported:** 2026-10-29 (Android phone emulator, `dev.forjahq.xyz` Desktop handoff)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Phone Settings → Profile & account offered email/password (broken under Auth captcha) beside Web login.
2. Web login portal showed **Forja could not apply the session** after Return to Forja / auto-handoff.
3. A second Return often succeeded; app log: `Failed host lookup: …supabase.co` then later `session handoff ok`.

## Root cause

Verified in emulator logcat:

1. Password path: `AuthApiException … captcha_failed` (no captcha token on native).
2. Handoff path: `signInWithBrowserTokens` → `setSession` → `getUser` fails with `AuthRetryableFetchException` / `Failed host lookup` for the Supabase host. Three retries finished in ~1s — too short for emulator DNS. Portal got `ok: false` apply body. Second Return after DNS recovered succeeded (`persisted=true`).

`sync_service.dart` `signInWithBrowserTokens` · `DesktopBrowserAuth` apply catch · portal `mintAndHandoffToDesktop` (single attempt).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I525-T01 | Phone Settings: Web login only (drop in-app email/password) | ✅ |
| 2 | I525-T02 | Warm Auth host DNS before browser handoff; longer `setSession` backoff (6 attempts) | ✅ |
| 3 | I525-T03 | Portal `mintAndHandoffToDesktop` auto-retries on `rejected` (transient apply) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I525-A01 | Phone Profile & account signed-out: Web login + signup only (no email/password fields) | ⬜ |
| 2 | I525-A02 | Emulator Web login: first Return/auto-handoff succeeds without manual second tap after a DNS blip | ⬜ |

## Links

- Related: [520](fixed/520-[fixed]-web-login-handoff-unreachable-after-apply-fail.md) (keep listening after apply fail)
- Related: [519](fixed/519-[fixed]-android-session-not-durable-cold-start.md)
