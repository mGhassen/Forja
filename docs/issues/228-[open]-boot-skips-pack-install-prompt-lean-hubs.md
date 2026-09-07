# 228 — Cloud packs auto-install (no install confirm)

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** `BootNeeds` · `PluginInstallCoordinator` · cloud lean sync

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I228-T01 | `BootNeeds`: Features hub ids + pending lean → warm runs | ✅ |
| 2 | I228-T02 | Splash silent-downloads all membership packs needing disk; clear deferred | ✅ |
| 3 | I228-T03 | Mid-session cloud add/remove: auto-install / silent purge + toast (View → Forja Packs); update prompts stay | ✅ |
| 4 | I228-T04 | Unit tests + changelog / feature docs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I228-A01 | Web adds pack → other device auto-downloads; toast “installed” with View → Forja Packs | ⬜ |
| 2 | I228-A02 | Cold start with pending lean membership hydrates on splash (no install confirm) | ⬜ |
| 3 | I228-A03 | Pack updates still toast + Update confirm; manual `forja://` / Settings Install still ask | ⬜ |

---

## Summary

**Contract:** Cloud membership = download on this device. No install/uninstall confirm for profile sync. Toast after install/remove (View opens Forja Packs). **Updates** still ask.

**Related:** BootNeeds chicken-egg (Features hubs without contributed nav) still fixed so splash warm runs.
