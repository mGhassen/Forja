# 213 — Engine + Nuvio plugin scripts on disk + init download progress

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `apps/forja/lib/shared/engine/`, `apps/forja/lib/shared/nuvio/`, splash / profile warm

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **3 / 7** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I213-T01 | `PluginScriptDiskStore` — Application Support `plugin_scripts_v1/` for engine + nuvio JS | ✅ |
| 2 | I213-T02 | `PluginRegistry` install/load/remove/repair + prefs→disk migration | ✅ |
| 3 | I213-T03 | `NuvioService` disk cache + migration + lean remove purge | ✅ |
| 4 | I213-T04 | `PluginInstallCoordinator` — cloud lean await, missing/update queue, progress notifier | ✅ |
| 5 | I213-T05 | Splash / profile status line for pack install; in-shell banner for mid-session updates | ✅ |
| 6 | I213-T06 | Unit tests for disk store, coordinator, registry install/remove | ✅ |
| 7 | I213-T07 | Splash / profile “Continue in background” when install slow, stuck, or failed (TV autofocus) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I213-A01 | Fresh cloud lean URLs → intro bottom status line → JS on disk → Play works | ⬜ |
| 2 | I213-A02 | Restored session: cloud pull completes before install queue; new pack appears without Settings | ⬜ |
| 3 | I213-A03 | Remote manifest version bump → next launch status “Checking/Updating…” → disk replaced | ⬜ |
| 4 | I213-A04 | Offline: no status spam; cached disk still loads | ⬜ |
| 5 | I213-A05 | Settings Remove pack deletes `engine/<hash>/`; Nuvio remove deletes scraper files | ✅ |
| 6 | I213-A06 | ATV: splash status + Continue in background autofocus; mid-session card non-focusable; extract batch unchanged | ⬜ |
| 7 | I213-A07 | Slow/stuck/failed pack install → Continue in background opens app; install keeps running (in-shell card) | ⬜ |

---

## Summary

Remote Engine / Nuvio plugin JS no longer lives in SharedPreferences strings. Pack **metadata** stays in prefs/KV; **script bodies** go under Application Support. Boot runs a coordinator that awaits cloud lean sync, installs missing packs, and refreshes when remote semver is newer — intro/profile splash show steps on the normal bottom status line; mid-session updates use the in-shell progress card.

### Root cause (before)

Prefs grew large with full JS trees; local vs remote load paths diverged; splash could warm before cloud lean finished on restored sessions.

### Related

- [stream-providers.md](../features/sources/stream-providers.md)
- NuvioMobile `PluginScraperCodeFileStore` (reference layout)
