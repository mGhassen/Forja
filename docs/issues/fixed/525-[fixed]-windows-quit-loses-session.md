# 525 — Windows quit loses Supabase session

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** host · sync · Windows / Linux secure store  
**Reported:** 2026-11-02 (quit app on Windows → account gate again)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 1** acceptance (manual Windows QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On Windows, sign in (device-link / Web login), quit Forja, relaunch → signed out; must reconnect.

## Root cause

`ForjaPlatformSecureStore` treated only Android (and macOS declined Keychain) as prefs-vault-primary. On Windows/Linux it wrote `flutter_secure_storage` then **deleted** the SharedPreferences vault copy. Credential Manager / libsecret alone dropped the session across quit; cold start found nothing.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I525-T01 | Windows/Linux prefs vault primary; do not wipe vault after DP write | ✅ |
| 2 | I525-T02 | Prefer vault on read; migrate leftover DP/Credential Manager → vault | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I525-A01 | Windows: sign in → quit → relaunch still signed in (same account) | ⬜ |

## Links

- [085](../085-[open]-desktop-involuntary-signout-dumps-login.md)
- [106](../106-[open]-desktop-session-profile-chrome-desync.md)
