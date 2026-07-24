# RFC-046 — Android TV device-code / QR account link

**Status:** open  
**Depends on:** [RFC-042](042-[open]-unified-auth-system.md), [RFC-034](034-[partial]-web-portal-landing.md)  
**Area:** `apps/forja` Android TV · `apps/web` `/connect` · Supabase Edge device-link  
**Version:** v1.0 theme (Bab Souika)

Link a Forja account to Android TV without typing email/password on the leanback remote. TV shows a short code + QR; the user approves on the portal at `/connect`. Edge mints a separate GoTrue session labeled for TV (same ownership model as desktop Web login).

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **0 / 8** acceptance (manual smoke) |
| **Current slice** | Implementation landed — web/TV acceptance smoke ⬜ |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R46-C01 | `device_link_codes` table (service_role only) | ✅ |
| 2 | R46-C02 | Edge `create-device-link` / `approve-device-link` / `poll-device-link` + TV session label | ✅ |
| 3 | R46-C03 | Portal `/connect` (RequireAuth, code entry, approve) | ✅ |
| 4 | R46-C04 | Flutter TV cold-start link screen (code + QR + poll + guest) | ✅ |
| 5 | R46-C05 | Settings Profile & account TV link entry + Connections UA label | ✅ |

---

## Acceptance (web)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R46-A01 | Signed-in user on `/connect` can approve a pending `user_code` | ⬜ |
| 2 | R46-A02 | Unauthenticated `/connect` redirects to login with return to `/connect?code=` | ⬜ |
| 3 | R46-A03 | Account → Connections shows “Forja Android TV” for device-link sessions | ⬜ |
| 4 | R46-A04 | Approving an expired or consumed code fails with a clear error | ⬜ |

---

## Acceptance (Android TV)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R46-A05 | Cold start without session shows link screen (code + QR + instructions) | ⬜ |
| 2 | R46-A06 | Continue as guest skips into the app without linking | ⬜ |
| 3 | R46-A07 | After portal approve, TV poll receives tokens and signs in (profiles → splash) | ⬜ |
| 4 | R46-A08 | Sign-out on TV returns to the link screen (account-bound local state cleared) | ⬜ |

---

## Summary

### Goals

- Leanback-friendly account link (device code + QR → portal `/connect`)
- Separate GoTrue session for TV; portal keeps its own session
- Guest remains available on TV cold start

### Non-goals

- Email/password or passkeys typed on the TV remote
- LAN pairing (RFC-022) for cloud identity
- Phone native deep links beyond HTTPS `/connect`
- Non-TV mobile cold-start account gate

### Related

- [RFC-042](042-[open]-unified-auth-system.md) — unified auth / desktop mint
- [Link Android TV](../features/accounts/tv-connect.md) — user guide
- Trakt device-code UX in Settings (precedent only)
