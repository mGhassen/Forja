# 219 — Green Play fails after every plugin pack update

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** plugin install · green Play · `CatalogSourcesSessionCache`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I219-T01 | `CatalogSourcesSessionCache.clearAll` on pack install / remove / local script change | ✅ |
| 2 | I219-T02 | Clear `PlayerStreamExtractCache` with the same pack-change hook | ✅ |
| 3 | I219-T03 | Green Play drops empty `fetchedPluginIds` before racing (re-extract empties) | ✅ |
| 4 | I219-T04 | Unit: `clearAll` wipes engine + stremio session entries | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I219-A01 | Unit: session cache `clearAll` leaves no engine/stremio rows | ✅ |
| 2 | I219-A02 | Unit: `engineStaleFetchedPluginIds` still marks empty fetches for refetch | ✅ |
| 3 | I219-A03 | App: update providers pack → green Play on a title already opened this session races fresh extracts (manual) | ⬜ |

---

## Summary

After a plugin pack update, hub `CatalogCache` was wiped but **Sources session RAM** kept `fetchedPluginIds` (including empties) for ~30 minutes. Green Play seeded from that cache, treated empty fetches as terminal, and showed **“None of the Forja plugins returned a working stream”** without re-running the new pack scripts. The green wifi icon on that screen is the resolve-failure badge (not a separate control).

**Root fix:** invalidate Sources session + player extract caches whenever a pack installs, removes, or a local checkout script body changes; green Play also strips empty fetched markers before the race so in-session empties can retry.

### Verify

```bash
cd apps/forja && flutter test test/sources_panel_filters_nuvio_lazy_test.dart test/engine_test.dart
# Manual: Play a title → update providers pack → green Play again (should re-extract)
```

## Related

- [218](fixed/218-[fixed]-dimatoon-green-play-probe-false-fail.md) — probe false-fail (different path)
- [043](fixed/043-[fixed]-dead-cache-full-auto-reresolve.md) — dead CDN re-resolve
