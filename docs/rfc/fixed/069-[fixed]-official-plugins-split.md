# RFC-069: Official packs under `plugins/` (providers / live / catalog)

**Status:** fixed  
**Depends on:** [RFC-068](068-[fixed]-engine-plugin-registry.md)  
**Area:** `plugins/`, `PluginRegistry`, Settings → Sources → Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Split monolith → three packs under `plugins/`; three dart-defines; wipe legacy `forjahq` pack |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R69-C01 | Repo `plugins/{providers,live,catalog}/manifest.json` (+ hops with providers) | ✅ |
| 2 | R69-C02 | Three dart-defines; `ensureOfficial` installs/refreshes all | ✅ |
| 3 | R69-C03 | One-shot wipe of legacy single `forjahq` / `forjahq-plugin` pack | ✅ |
| 4 | R69-C04 | Env / CI / docs / tests updated | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R69-A01 | No root mega-manifest; three pack ids | ✅ |
| 2 | R69-A02 | Hops ship in providers pack | ✅ |
| 3 | R69-A03 | `FORJA_HQ_{PROVIDERS,LIVE,CATALOG}_MANIFEST_URL` required | ✅ |
| 4 | R69-A04 | ensureOfficial installs missing + version-refresh per pack | ✅ |
| 5 | R69-A05 | Upgrade removes old `packId: forjahq` / old path pack | ✅ |
| 6 | R69-A06 | Settings shows three official packs; Retry reinstalls all | ✅ |
| 7 | R69-A07 | Feature docs + changelog | ✅ |
| 8 | R69-A08 | engine_test loads from split packs | ✅ |

---

## Summary

Replace the single **ForjaHQ** monolith (`forjahq-plugin/manifest.json`) with three official packs under repo-root **`plugins/`**: providers (+ hops), live, catalog. App auto-installs all three from separate dart-defines and migrates off the legacy one-pack install.

### Related

- [RFC-067](067-[fixed]-forjahq-remote-plugin-pack.md)
- [RFC-068](068-[fixed]-engine-plugin-registry.md)
