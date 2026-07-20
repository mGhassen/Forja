# RFC-042 — Unified auth system (web + Flutter)

**Status:** open  
**Depends on:** [RFC-034](034-[partial]-web-portal-landing.md), [RFC-006](006-[partial]-supabase-sync.md)  
**Area:** `apps/web` auth · `apps/forja` SyncService / account entry  
**Version:** v1.0 theme (Bab Souika)

Patterns adapted from Guepard console auth (hook facades, MFA AAL2, OAuth callback errors, desktop session ownership) without copying Tauri/sidecar architecture.

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **9 / 16** acceptance |
| **Current slice** | Desktop session Keychain persist (release) shipped — remaining web/Flutter smoke ⬜ |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R42-C01 | Shared `@forja/auth` + `@forja/auth/react` — full provider, MFA/OAuth UI, gates | ✅ |
| 2 | R42-C02 | Web + admin are thin hosts (inject Supabase + feature flags only) | ✅ |
| 3 | R42-C03 | Session ownership — handoff lock + portal releases RT to desktop | ✅ |
| 4 | R42-C04 | Flutter — secure session storage, in-flight refresh, MFA challenge, OAuth via Web login | ✅ |
| 5 | R42-C05 | Edge `mint-desktop-session` — second GoTrue session for desktop; portal keeps its own | ✅ |

---

## Acceptance (web)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R42-A01 | Password + passkey + optional Google OAuth on `/login` | ⬜ |
| 2 | R42-A02 | OAuth/PKCE `/auth/callback` maps errors (otp_expired, verifier mismatch) | ⬜ |
| 3 | R42-A03 | Optional TOTP MFA enroll in Account settings | ⬜ |
| 4 | R42-A04 | After password/OAuth, AAL1→AAL2 challenge on `/login/mfa` before app access | ⬜ |
| 5 | R42-A05 | Sign out this browser (local) vs all devices (global) | ✅ |
| 6 | R42-A06 | Desktop handoff mints session B; portal stays signed in (no Auth wipe) | ✅ |
| 7 | R42-A14 | Desktop `/login?desktop_*` never shows credentials while session hydrates or when already signed in | ✅ |
| 8 | R42-A15 | Account → Connections lists active sessions (where / since / last active / IP) | ✅ |
| 9 | R42-A16 | Connections can revoke one session or sign out all devices | ✅ |

---

## Acceptance (Flutter)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R42-A07 | Session persisted via secure storage on desktop | ✅ |
| 2 | R42-A08 | Single in-flight `refreshSession` (boot/resume/focus) | ⬜ |
| 3 | R42-A09 | Password sign-in shows TOTP challenge when MFA enrolled | ⬜ |
| 4 | R42-A10 | Web login / OAuth completes MFA on portal then hands desktop its own session | ⬜ |
| 5 | R42-A11 | Browser token apply prefers access+refresh (no RT race) | ✅ |
| 6 | R42-A12 | Feature + changelog docs match shipped UX | ✅ |
| 7 | R42-A13 | After Web login, portal and desktop remain signed in on separate refresh tokens | ✅ |

---

## Summary

Unify Forja auth around one Supabase project with Guepard-grade structure: thin facades, human error map, optional MFA/OAuth, and separate sessions for portal vs desktop (edge mint; no shared refresh token).

### Goals

- Portal and app each own a distinct refresh token after Web login
- Optional TOTP + Google OAuth without blocking password/passkey
- Flutter follows the same session apply / refresh / MFA rules

### Non-goals

- Cookie SSR (`@supabase/ssr`) migration
- Better Auth / IdP swap
- Magic link (can enable later via config)
- Tauri keychain IPC (Flutter uses `flutter_secure_storage`)

### Related

- [Issue 085](../issues/085-[open]-desktop-involuntary-signout-dumps-login.md) — session loss → login + wipe (no Guest portal leak)
- Guepard: `packages/supabase` hooks + MFA + desktop rehydrate `inFlight`
