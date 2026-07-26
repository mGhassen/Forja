# 111 — macOS Keychain consent + local-file fallback

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** macOS secure storage · Keychain · Trakt / Simkl / session

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I111-T01 | `ForjaPlatformSecureStore` Keychain consent (unset / accepted / declined); no Keychain I/O until accepted | ✅ |
| 2 | I111-T02 | macOS in-app explain/ask screen before Supabase hydrate; decline → prefs vault only | ✅ |
| 3 | I111-T03 | Route Trakt / Simkl / MDBList through platform store (stop bare `FlutterSecureStorage` login Keychain) | ✅ |
| 4 | I111-T04 | Docs + changelog (platforms / cloud-sync / issue index) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I111-A01 | Fresh macOS install: Forja explains Keychain vs local file before any system Keychain password dialog | ⬜ |
| 2 | I111-A02 | Choosing **Use local file** never shows the login-Keychain password dialog; account / Trakt tokens still persist across relaunch | ⬜ |
| 3 | I111-A03 | Choosing **Use Keychain** may show one OS dialog mentioning `flutter_secure_storage_service` (explained in-app); secrets work after Always Allow | ⬜ |

---

## Summary

The system dialog *“Forja wants to use … `flutter_secure_storage_service`”* is macOS Keychain ACL for `flutter_secure_storage`. The 1.2.434 session path already preferred Data Protection / prefs vault, but **Trakt, Simkl, and MDBList** still used bare `FlutterSecureStorage()` (login Keychain) and legacy migrate could still prompt with no in-app explanation.

### Shipped

- One-time macOS consent screen (`MacOsKeychainConsentScreen`) before Supabase init when consent is unset.
- Decline → SharedPreferences vault only (plain app-file storage).
- Accept → existing DP Keychain (sandboxed) + optional one-shot login-Keychain migrate.
- Tracker / MDBList secrets go through `ForjaPlatformSecureStore`.

## Related

- [Cloud sync](../features/settings/cloud-sync.md)
- [Platforms](../features/getting-started/platforms.md)
- Changelog 1.2.434 Keychain-on-update fix (session path only)
