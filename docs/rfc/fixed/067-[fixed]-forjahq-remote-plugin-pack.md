# RFC-067: ForjaHQ remote plugin pack

**Status:** fixed  
**Depends on:** [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md), [RFC-065](065-[open]-live-forja-scrapers.md)  
**Area:** `forjahq-plugin/`, `apps/forja/lib/shared/engine/`, Settings → Sources → Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 5 / 5** components · **10 / 10** acceptance |
| **Current slice** | ForjaHQ remote pack shipped — APK is engine JS shell + goat/gasm/sportsembed unlock only |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R67-C01 | Repo-root `forjahq-plugin/` (`manifest.json`, providers, live, catalog) | ✅ |
| 2 | R67-C02 | `EngineService.officialManifestUrl` + first-boot install + prefs script cache | ✅ |
| 3 | R67-C03 | Settings → Forja: ForjaHQ pack, Add plugin, Refresh, Remove | ✅ |
| 4 | R67-C04 | Live/catalog via installed JS only; Rust native catalog dispatch removed | ✅ |
| 5 | R67-C05 | APK retains goat/gasm/sportsembed host unlock assets only | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R67-A01 | No VOD/live/catalog JS in APK assets (except host unlock) | ✅ |
| 2 | R67-A02 | First boot auto-installs ForjaHQ from `officialManifestUrl` when offline cache empty | ✅ |
| 3 | R67-A03 | Install/refresh fails when any manifest `entry` script is missing | ✅ |
| 4 | R67-A04 | User can paste extra manifest URLs (community packs) | ✅ |
| 5 | R67-A05 | Settings Live Forja plugins list entries from all installed packs | ✅ |
| 6 | R67-A06 | `engine_test.dart` reads pack via path helper; audit CLI requires `--assets=DIR` (no baked pack path) | ✅ |
| 7 | R67-A07 | Feature docs + changelog describe remote ForjaHQ pack | ✅ |
| 8 | R67-A08 | Call sites use `ensureOfficialInstalled` (no `ensureBundledInstalled` alias) | ✅ |
| 9 | R67-A09 | ForjaHQ pack removable like other manifests | ✅ |
| 10 | R67-A10 | `manifest.json` schema unchanged (`schema`, `name`, `version`, `plugins[]`) | ✅ |

---

## Summary

Forja is an **engine JS shell**. Official provider scripts live in public repo-root **`forjahq-plugin/`** (pack name **ForjaHQ**, team Forja Team). The app ships **`EngineService.officialManifestUrl`** only and installs scripts over HTTP on first boot (or via Settings **Refresh**). Scripts cache in SharedPreferences; no `rootBundle` fallback.

### APK-only (host unlock)

- `apps/forja/assets/plugins/live/goat/`
- `apps/forja/assets/plugins/live/gasm/`
- `apps/forja/assets/plugins/live/sportsembed/` (WatchFooty wasm unlock)

### Out of scope

Webstreaming green Play, torrent, Nuvio, Stremio, IPTV — unchanged.

### Related

- [RFC-060](fixed/060-[fixed]-enginejs-sources-forja-tab.md) — Sources Forja tab
- [RFC-065](065-[open]-live-forja-scrapers.md) — live plugins (now remote)
- [forjahq-plugin/README.md](../../../forjahq-plugin/README.md)
