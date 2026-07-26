# 111 — macOS Keychain consent + local-file fallback

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** macOS secure storage · Keychain · Trakt / Simkl / session

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I111-T01 | `ForjaPlatformSecureStore` Keychain consent; default macOS = local prefs vault (no Keychain) | ✅ |
| 2 | I111-T02 | No boot prompt — explain dialog only when enabling Keychain from Settings | ✅ |
| 3 | I111-T03 | Route Trakt / Simkl / MDBList through platform store (stop bare `FlutterSecureStorage` login Keychain) | ✅ |
| 4 | I111-T04 | Docs + changelog (platforms / cloud-sync / issue index) | ✅ |
| 5 | I111-T05 | Settings → About → Privacy toggle; Material dialog (no yellow underline bleed) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I111-A01 | Fresh macOS launch never shows Keychain explain screen or system Keychain password dialog | ⬜ |
| 2 | I111-A02 | Account / Trakt tokens persist across relaunch using local file storage by default | ⬜ |
| 3 | I111-A03 | Enabling **Store secrets in Keychain** shows the explain dialog first; Accept may show one OS dialog mentioning `flutter_secure_storage_service` | ⬜ |

---

## Summary

The system dialog *“Forja wants to use … `flutter_secure_storage_service`”* is macOS Keychain ACL for `flutter_secure_storage`. Trakt / Simkl / MDBList used bare `FlutterSecureStorage()` (login Keychain).

### Shipped

- **Default:** local prefs vault on macOS — no boot ask, no Keychain I/O.
- **Opt-in:** Settings → About → Privacy → **Store secrets in Keychain** shows an `AlertDialog` explain/ask, then may touch Keychain.
- Tracker / MDBList secrets go through `ForjaPlatformSecureStore`.

## Related

- [Cloud sync](../features/settings/cloud-sync.md)
- [Platforms](../features/getting-started/platforms.md)
