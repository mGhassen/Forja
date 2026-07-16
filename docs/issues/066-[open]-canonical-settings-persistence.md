# 066 — Canonical settings persistence

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Settings, Rust KV (`forja_engine_store.json`), secure storage, Nuvio, WebStreamr, Debrid

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **4 / 6** acceptance (device smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I66-T01 | Atomic writes for `forja_engine_store.json` + boot seeding after `Engine.init` | ✅ |
| 2 | I66-T02 | Migrate Nuvio addon metadata + WebStreamr non-secret prefs into canonical KV | ✅ |
| 3 | I66-T03 | Secure-settings adapter: Debrid / Jackett / Prowlarr / WebStreamr secrets | ✅ |
| 4 | I66-T04 | Schema migration marker + restart round-trip tests (no secrets in JSON) | ✅ |
| 5 | I66-T05 | Feature docs + changelog: local canonical file vs manual Export/Import | ✅ |
| 6 | I66-T06 | Stop legacy prefs migration from re-running every boot and clobbering KV (Stremio addons) | ✅ |
| 7 | I66-T07 | Single settings home: merge prefs+KV into store, purge prefs copies (`settings_canonical_v1`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I66-A01 | Change playback/provider/Nuvio/WebStreamr settings → kill app → values restore | ⬜ |
| 2 | I66-A02 | Credentials survive restart via Keychain/Keystore; never appear in `forja_engine_store.json` | ✅ |
| 3 | I66-A03 | Interrupted write does not leave a truncated/corrupt settings file | ✅ |
| 4 | I66-A04 | Platform defaults seed successfully (engine ready before seed) | ✅ |
| 5 | I66-A05 | IPTV catalogs, My List, watch history, stream caches unchanged by this work | ✅ |
| 6 | I66-A06 | Docs distinguish automatic local persistence from Backup Export/Import | ✅ |

---

## Summary

Settings, sources, addons, and auth were split across Rust KV, SharedPreferences, and secure storage. Boot could seed defaults before the engine opened `forja_engine_store.json`, and several secrets sat in plaintext prefs/KV.

### Shipped

- Atomic JSON flush + `.bak` recovery in `crates/storage`
- Platform default seed after `Engine.init()` in bootstrap
- Nuvio addon metadata + WebStreamr non-secret prefs → canonical KV
- Debrid / Jackett / Prowlarr / WebStreamr MFP+TMDB secrets → `SecureSettings`
- Schema marker `settings_schema_v2`; export/import version 2
- Docs + changelog updated
- Legacy prefs migration gated on `legacy_prefs_migrated_v1` and never overwrites existing KV keys (fixes Stremio addons wiped on restart)
- Single settings home: merge prefs+KV (Stremio by baseUrl), purge SharedPreferences settings keys, marker `settings_canonical_v1`

### Out of scope

- IPTV channel catalogs
- Watch history / My List / continue watching content
- Stream extract caches / torrent temp / update installers
- Full Export/Import field expansion beyond this migration (manual backup still a snapshot)

### Related

- [backup-restore](../features/settings/backup-restore.md)
- [cache-data](../features/settings/cache-data.md)
- [playback-settings](../features/settings/playback-settings.md)
- [Issue 044](fixed/044-[fixed]-settings-cache-data-cleaner.md)
