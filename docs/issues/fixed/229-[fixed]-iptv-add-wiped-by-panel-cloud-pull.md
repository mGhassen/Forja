# 229 — IPTV add wiped by portal-panel cloud pull

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** `iptv_controller_portal.dart` · `sync_domain_bridge.dart` · `preparePortalPanel`  
**Reported:** 2026-09-07

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0/1** acceptance smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I229-T01 | Track IPTV dirty gen; flush pending IPTV before portal-panel / soft pull | ✅ |
| 2 | I229-T02 | `addManual` / edit / import await `flushIptvPushIfDirty` before panel pull | ✅ |
| 3 | I229-T03 | Skip cloud IPTV apply while local inventory still dirty after failed flush | ✅ |
| 4 | I229-T04 | Soft-pull flush includes dirty IPTV (not only debounced timer key) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I229-A01 | Manual Xtream add stays in the portal list after verify success | ⬜ |

---

## Summary

**Symptom:** Adding an IPTV portal in the app looked like it did nothing (or vanished immediately). Multiple servers failed the same way. Logs showed nav `pushProfileSettings` only — no IPTV upsert.

**Root cause:** `addManual` saved locally and scheduled a **3s** IPTV sync push, then `openPortalPanel` → `preparePortalPanel` → `pullIptvPortalsFromCloud` with **empty cloud** (push not landed yet). Cloud-is-master apply dropped the new local row. Soft-pull on focus had the same race when dirty IPTV was not in the flush set.

**Fix:** IPTV dirty generation (like nav/prefs). Flush unsynced IPTV before any cloud portal pull; await flush after add/edit/import; skip apply while still dirty.
