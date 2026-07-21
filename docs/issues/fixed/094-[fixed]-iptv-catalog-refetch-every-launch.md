# 094 — IPTV catalog re-fetches on every app launch

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4/4** fix · **0/1** smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I94-T01 | Persist Live/Movies/Series snaps to app-support JSON files (hashed portal key) | ✅ |
| 2 | I94-T02 | Hydrate session cache from disk before cold bootstrap; Reload overwrites files | ✅ |
| 3 | I94-T03 | Clear disk + session on portal delete/edit, Settings IPTV cache clear, sign-out | ✅ |
| 4 | I94-T04 | Feature docs + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I94-A01 | Quit + reopen: last portal catalog opens without “Loading catalog” verbose panel | ⬜ |

---

## Summary

Catalog shelves lived only in a process-static session map. App kill emptied it, so every launch ran `bootstrapPortalCatalog` (verbose progress). Counts were prefs-backed; streams/categories were not.

**Root fix:** `IptvCatalogDiskStore` writes one JSON file per portal+shelf under application support; open hydrates before bootstrap; Reload / delete / Settings clear / sign-out invalidate disk.

## Related

- [IPTV Xtream](../features/live/iptv-xtream.md)
- [Cache & data](../features/settings/cache-data.md)
