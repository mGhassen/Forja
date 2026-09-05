# RFC-082: Account / profile / guest local data scope

**Status:** open  
**Depends on:** [RFC-036](036-[open]-accounts-iptv-profile-settings.md), issue 213 (plugin disk scope), issue 217 (IPTV wipe-on-switch)  
**Area:** sync / settings / local storage

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 5** components · **6 / 10** acceptance |
| **Current slice** | LocalDataScope + Data & backup clears for watch / scores / extract / IPTV catalog caches |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R82-C01 | `LocalDataScope` (`base@accountId:profileId`, guest = `local:default`) | ✅ |
| 2 | R82-C02 | SyncService configures LocalDataScope + plugin disk + IPTV catalog disk + provider scores together | ✅ |
| 3 | R82-C03 | Settings → Data & backup clears only the active identity for scoped stores | ✅ |
| 4 | R82-C04 | IPTV portal inventory / favorites / passwords path-or-key scoped (replace wipe-only) | ⬜ |
| 5 | R82-C05 | Synced settings KV path-scoped (retire wipe+pull as sole isolation) | ⬜ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R82-A01 | Continue watching / watched marks / My List prefs keys are identity-scoped | ✅ |
| 2 | R82-A02 | Hub `catalog_cw_*` prefs are identity-scoped | ✅ |
| 3 | R82-A03 | Stream extract cache + provider reliability scores are identity-scoped | ✅ |
| 4 | R82-A04 | IPTV alive / channel-scan / shelf LRU / catalog disk under active identity | ✅ |
| 5 | R82-A05 | Settings clear continue watching / scores / IPTV catalog cache does not wipe another profile | ✅ |
| 6 | R82-A06 | One-time migrate bare legacy keys into the first active identity | ✅ |
| 7 | R82-A07 | Images / WebView / update installers documented as device-shared ephemeral | ✅ |
| 8 | R82-A08 | IPTV portal list + Keychain passwords isolated without relying only on wipe | ⬜ |
| 9 | R82-A09 | `forja_engine_store.json` / synced domains path-scoped per identity | ⬜ |
| 10 | R82-A10 | Backup export/import is active-identity only (no other profile bleed) | ⬜ |

---

## Summary

Product rule: **all user-managed local data is account / profile / Guest scoped.** Device-wide SharedPreferences / KV for watch history, scores, and Settings clears was a bug.

Guest = `accounts/local/profiles/default` (same as plugin JS disk). Signed-in = Supabase user id + profile id.

### Goals

- Clearing Data & backup never touches another profile or the other of Guest vs signed-in
- Profile switch rebinds stores; other identities’ rows stay on disk
- Ephemeral device caches (images, WebView, update installers, torrent temp) may stay shared

### Related

- [Cache & data](../features/settings/cache-data.md)
- [Cloud sync](../features/settings/cloud-sync.md)
- Plugin disk: `PluginScriptDiskStore`
