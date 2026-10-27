# 504 — Signup confirm lands on Site URL `/#` instead of profiles

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** web · auth · signup  
**Reported:** 2026-10-27 (prod: confirm link → `https://www.forjahq.xyz/#`)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

After signup, clicking the email **Confirm email** link opens the marketing home at `https://www.forjahq.xyz/#` instead of Who’s watching / create profile (`/account/profiles`).

## Root cause

1. Hosted Confirm signup template may still use Supabase `ConfirmationURL` (or redirect allowlist falls back to **Site URL**). That lands on `/` with `#access_token=…&type=signup`.
2. `@supabase/supabase-js` `detectSessionInUrl` consumes the hash on `/`, leaving `/#`, with no navigation to `/auth/callback` → `/account/profiles`.
3. `exchangeAuthCode` only handled `?code=` / `?token_hash=` — not implicit hash tokens.

Preferred email shape remains `templates/confirmation.html` (`token_hash` → `/auth/callback`). Hosted Dashboard does not auto-sync that file.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I504-T01 | Relocate Site URL auth redirects to `/auth/callback` before `createClient`; skip `detectSessionInUrl` on the dying document | ✅ |
| 2 | I504-T02 | `exchangeAuthCode` accepts `#access_token` / `#refresh_token` (and session-already-present after detect) → next `/account/profiles`; signup copy matches | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I504-A01 | Confirm link that would have hit `/#access_token=…` ends on `/account/profiles` signed in | ✅ (code path) |
| 2 | I504-A02 | Hosted Dashboard Confirm signup HTML pasted from `templates/confirmation.html` + redirect allowlist includes `/auth/callback` | ⬜ ops |

## Links

- `packages/forja-auth/src/callback.ts`
- `apps/web/src/lib/supabase.ts`
- `apps/web/supabase/templates/confirmation.html`
- `apps/web/supabase/README.md` (hosted template paste)
