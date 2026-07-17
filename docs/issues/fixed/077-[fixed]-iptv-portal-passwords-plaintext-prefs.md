# 077 — IPTV portal passwords not in Keychain

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV, secure storage, Settings backup CSV

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 4** acceptance (device smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I77-T01 | macOS sandbox `keychain-access-groups` for `com.forja.app` (fix `-34018`) | ✅ |
| 2 | I77-T02 | `IptvStore`: passwords in `SecureSettings.iptvPortalPasswords`; prefs metadata only | ✅ |
| 3 | I77-T03 | Migrate legacy plaintext prefs passwords → Keychain on load; CSV export stays plaintext | ✅ |
| 4 | I77-T04 | Feature docs + changelog + backup export includes IPTV password vault key | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I77-A01 | After save, `pt_iptv_verified_portals` prefs JSON has no `password` fields | ✅ |
| 2 | I77-A02 | Export CSV still includes url/username/password in plaintext | ✅ |
| 3 | I77-A03 | Import CSV still adds new portals and stores passwords in Keychain | ✅ |
| 4 | I77-A04 | macOS: open Settings → Data & backup; no `SecureSettings` `-34018` spam; portals still play | ⬜ |

---

## Summary

Xtream portal passwords were stored in SharedPreferences as plaintext JSON (`pt_iptv_verified_portals`). That is app-private but not Keychain/Keystore at-rest protection.

### Shipped

- macOS Debug/Release entitlements: `keychain-access-groups` → `$(AppIdentifierPrefix)com.forja.app`
- `SecureSettings.iptvPortalPasswords` (`iptv_portal_passwords_v1`) — JSON map `url|username` → password
- `IptvStore.load` migrates legacy prefs passwords into Keychain then strips them from prefs
- `IptvStore.save` writes Keychain first; only falls back to prefs passwords if Keychain write fails
- CSV export/import unchanged format (plaintext passwords in the user-chosen file)
- Settings backup `secure_storage` includes the IPTV password vault key

### Out of scope

- Channel history rows that still embed `portalPass` in prefs (separate cleanup)
- Encrypting cloud sync IPTV payloads
- Web remote settings storage (Supabase)

### Related

- [backup-restore](../features/settings/backup-restore.md)
- [iptv-xtream](../features/live/iptv-xtream.md)
- [Issue 066](066-[open]-canonical-settings-persistence.md) (other secrets already in SecureSettings)
