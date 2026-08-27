# RFC-068: Engine PluginRegistry

**Status:** fixed  
**Depends on:** [RFC-067](067-[fixed]-forjahq-remote-plugin-pack.md)  
**Area:** `apps/forja/lib/shared/engine/plugin_registry.dart`, Settings → Sources → Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **5 / 5** components · **10 / 10** acceptance |
| **Current slice** | Registry extract + pack-scoped keys + transactional install + version-aware official update |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R68-C01 | `PluginRegistry` — list/install/refresh/remove/ensureOfficial/script cache | ✅ |
| 2 | R68-C02 | Pack-scoped prefs keys (`engine_js_*_v2`) + v1 migrate | ✅ |
| 3 | R68-C03 | Transactional install (fetch-all then write) | ✅ |
| 4 | R68-C04 | Manifest `id` → `EnginePack.packId`; drop `bundled` | ✅ |
| 5 | R68-C05 | Official ensure refreshes when remote version > local | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R68-A01 | EngineService extract paths load scripts via registry | ✅ |
| 2 | R68-A02 | Two packs cannot share a plugin id (install refuses) | ✅ |
| 3 | R68-A03 | Failed install writes no prefs for that attempt | ✅ |
| 4 | R68-A04 | Script keys scoped by sourceUrl hash | ✅ |
| 5 | R68-A05 | One-shot migrate from packs_v1 / unscoped scripts | ✅ |
| 6 | R68-A06 | ForjaHQ manifest has stable `id: forjahq` | ✅ |
| 7 | R68-A07 | ensureOfficial auto-refresh when version bumps | ✅ |
| 8 | R68-A08 | Feature docs + changelog | ✅ |
| 9 | R68-A09 | Unit tests: keys, collision, semver, migrate smoke | ✅ |
| 10 | R68-A10 | No sha256/signing in this slice | ✅ |

---

## Summary

Professionalize the Forja engine pack lifecycle: a dedicated **PluginRegistry** owns install/refresh/remove/cache; **EngineService** stays the extract host. Pack-scoped script prefs prevent cross-pack clobber. Install is transactional. Official pack updates when remote `version` is newer. Hashing/signing deferred.

### Related

- [RFC-067](067-[fixed]-forjahq-remote-plugin-pack.md)
- [RFC-060](060-[fixed]-enginejs-sources-forja-tab.md)
