# 478 — Web login from Forja hands off the already signed-in portal account

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** web portal · desktop Web login · RFC-124  
**Reported:** 2026-10-24 (found while planning account switching)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Forja desktop → Sign in with Web login opens the portal `/login` page with a desktop callback. If the browser is already signed in to the portal as account A, the page hands off A to the app immediately. A user who wants to add account B to the app cannot: the portal never shows the sign-in form.

## Root cause

`apps/web/src/pages/login-page.tsx:160-178` runs the desktop handoff as soon as `user` is set when `desktop_callback` is present. The edge function `mint-desktop-session` mints a session for whoever calls it, so the app receives A again.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I478-T01 | `/login` with `desktop_switch=1` and a signed-in user shows **Continue as <email>** / **Use another account** (local portal sign-out, then the form) instead of auto-handoff; without the flag nothing changes. Same choice on `/connect` with `switch_account=1` (TV device link auto-approved the signed-in browser user after a 5 s countdown) | ✅ |
| 2 | I478-T02 | Forja desktop add-account mode appends `desktop_switch=1` to the portal login URL; TV add-account mode appends `switch_account=1` to the connect URL | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I478-A01 | Signed-in browser + `desktop_switch=1` → choice shown, no handoff until the user picks | ⬜ |
| 2 | I478-A02 | Plain desktop Web login (no flag) still hands off the signed-in user as before | ⬜ |

## Links

- [RFC-124](../rfc/124-[open]-multi-account-switching.md) — C09
