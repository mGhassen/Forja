# 522 — Device-link `/connect?code=` stolen as PKCE auth redirect

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** web · accounts · device link  
**Reported:** 2026-11-02 (QR click → portal PKCE 400)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Click / scan the Android TV / desktop device-link QR while already signed in on the portal. Instead of `/connect` auto-approve, the browser lands on auth callback with “Open the sign-in link in the same browser…” and `POST /auth/v1/token?grant_type=pkce` returns 400.

## Root cause

`relocateAuthRedirectToCallback` (`packages/forja-auth/src/callback.ts`) treated any `?code=` as a Supabase PKCE auth code, including device-link user codes on `/connect?code=…` and `/login?next=/connect&code=…`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-T01 | Skip device-link `?code=` in `relocateAuthRedirectToCallback` (`/connect` + `next=/connect`) | ✅ |
| 2 | I522-T02 | Unit coverage for connect / login-return / Site URL PKCE relocate | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-A01 | `npx tsx packages/forja-auth/src/callback.relocate.test.ts` passes | ✅ |
| 2 | I522-A02 | Manual: click QR while signed in on portal → `/connect` countdown / approve (not PKCE error) | ⬜ |

## Links

- Feature: [tv-connect](../../features/accounts/tv-connect.md)
- Related RFC: [046](../../rfc/046-[open]-android-tv-device-link.md)
