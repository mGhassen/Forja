# RFC-094: Community packs — URL-scoped identity

**Status:** partial  
**Depends on:** [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md) · [RFC-086](fixed/086-[fixed]-addons-packs-feature-vs-navbar.md)  
**Area:** engine packs / Features / community install

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** components · **8 / 8** acceptance (hub slice) · **0 / 4** deferred (providers) |
| **Current slice** | Hub install + Features host nav ids + pack-scoped catalog resolve shipped; providers deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R94-C01 | Install allows duplicate plugin ids across packs; unique within pack only | ✅ |
| 2 | R94-C02 | Host-owned Features/rail id from `sourceUrl` for non-official-tree packs | ✅ |
| 3 | R94-C03 | Hub catalog resolve threads `packSourceUrl` (KitShell → MetaRuntime → runCatalog) | ✅ |
| 4 | R94-C04 | Provider / extract / My List / JS registry full pack-scoping | ⏭️ |

---

## Acceptance (hub slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R94-A01 | Two community packs may share the same plugin `id` — install succeeds | ✅ |
| 2 | R94-A02 | Plugin id still unique **inside** one manifest | ✅ |
| 3 | R94-A03 | Community hub Features/rail key is `p_<urlHash>_<authorTabId>` (not bare author tabId) | ✅ |
| 4 | R94-A04 | Official `plugins/hubs/…` tree keeps author `tabId` (stable prefs/cloud) | ✅ |
| 5 | R94-A05 | KitShell / MetaRuntime / runCatalog resolve hub by `(sourceUrl, pluginId)` | ✅ |
| 6 | R94-A06 | Pack enable still pins hub tab at end of Features order (RFC-086 A17) using host nav id | ✅ |
| 7 | R94-A07 | SDK docs: plugin ids are pack-local; chrome ids are host-owned | ✅ |
| 8 | R94-A08 | Unit tests: collision install OK + hostNavId + sourceUrl disambiguation | ✅ |

---

## Acceptance (providers — deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R94-A09 | Sources / extract resolve by pack when plugin ids collide | ⏭️ |
| 2 | R94-A10 | EngineRuntime JS registry key includes urlHash | ⏭️ |
| 3 | R94-A11 | MetaCache / My List entry keys pack-scoped | ⏭️ |
| 4 | R94-A12 | ProviderRuntimeConfig keyed by pack ref | ⏭️ |

---

## Summary

Community packs are **not** Forja-owned. Authors cannot mint globally unique plugin ids or Features tab ids.

**Canonical identity** = install `sourceUrl` (already scopes scripts/disk via `urlHash`).  
**Plugin `id`** = local within one pack.  
**Features/rail id** = host-derived for arbitrary URLs; official `plugins/hubs/…` paths keep author `tabId` for existing prefs/cloud.

Supersedes R68-A02 (“two packs cannot share a plugin id”) for community — frozen row stays historical.

### Related

- [navigation-bar](../features/settings/navigation-bar.md)
- [RFC-068](fixed/068-[fixed]-engine-plugin-registry.md)
