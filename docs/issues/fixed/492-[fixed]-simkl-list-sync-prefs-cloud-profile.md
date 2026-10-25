# 492 — Simkl list sync prefs not in cloud profile

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Settings · Connected services · Simkl · profile_settings  
**Reported:** 2026-10-26 (mode / auto sync were SharedPreferences-only)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** · A **0/1** |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Changing **How should lists sync?** or **Auto sync lists on My List** stayed on that device. Another device / profile pull did not get the prefs. Simkl login was never supposed to leave the device.

## Root cause

`simkl_list_sync_mode` / `simkl_auto_sync_lists` wrote scoped SharedPreferences only. `exportPreferences` / `importPreferences` and the prefs push hook did not include them.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I492-T01 | Export/import + wipe defaults for both keys under `playback` | ✅ |
| 2 | I492-T02 | `SimklService.onListSyncPrefsWrite` → debounced preferences push | ✅ |
| 3 | I492-T03 | Web `PreferencesPayload` types + cloud-sync feature guide | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I492-A01 | Device A sets Merge + Auto sync → Device B same profile pulls both; Simkl token still device-local | ⬜ |

## Links

- [486](../486-[open]-simkl-auto-sync-lists-on-my-list-open.md) · [467](../467-[open]-cross-account-simkl-connected-secrets-isolation.md)
