# 294 — IPTV first portal select stays on “Choose a portal”

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** IPTV · Portals panel · EngineCache

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I294-T01 | Stop stamping first inventory portal as `portalStoreKey` when `iptv.active` is empty | ✅ |
| 2 | I294-T02 | Soft portal select wipes EngineCache for the hub plugin (clear poisoned empty cover) | ✅ |
| 3 | I294-T03 | Panel store→vault mirror must not clear `iptv.active` on unresolved key | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I294-A01 | With no active portal, click the first Portals row → Live catalog loads (not “Choose a portal”) | ⬜ |
| 2 | I294-A02 | Chip / row show that portal; Movies / Series also load | ⬜ |

---

## Summary

**Symptom:** Selecting the first IPTV portal highlighted the row / chip but the grid stayed on **Choose a portal**. Other portals often worked.

**Root cause:** With no vault active, host feed params still stamped the **first** portal’s `portalStoreKey`. Pack feed correctly returned the empty cover (`iptvResolveActive` → null). That empty envelope was cached under the first portal’s key. Selecting that portal soft-bumped without wiping EngineCache → cache hit → empty cover forever.

**Fix:** Resolve active portal from vault only (no first-row fallback); wipe EngineCache on soft select; mirror must not clear active when store cannot resolve the key.
