# 218 — كرتون green Play fails while Sources stream plays

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** DimaToon provider · green Play probe · `provider_runtime_config`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I218-T01 | Skip CDN probe for `dimatoon` / `engine:dimatoon` (trust extract) | ✅ |
| 2 | I218-T02 | `validateStreamSourceForCheck` trusts DimaToon extract URLs | ✅ |
| 3 | I218-T03 | Issue + changelog + كرتون feature tip | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I218-A01 | Unit: builtins profile for `engine:dimatoon` / `dimatoon` is `AnimeProbeMode.skip` | ✅ |
| 2 | I218-A02 | App: كرتون details → green Play opens player for a title that Sources → DimaToon already lists (manual) | ⬜ |

---

## Summary

DimaToon extract returned a playable MP4 (`streams=1` in engine logs). Opening Sources (white link) listed the row and tapping it played. Green Play raced the same extract, then **HTTP HEAD/Range probe** failed on the CDN → “None of the Forja plugins returned a working stream.”

Sources → tap skips the probe and opens the player directly (`_playStremio` / `StremioPlayable`). Green Play uses `buildProbedEngineCatalogSources` → `probeSourcesPanelStream`.

**Root fix:** same trust-extract pattern as MovieBlast / NetMirror — `AnimeProbeMode.skip` for DimaToon in builtins + soft check in `validateStreamSourceForCheck`.

### Verify

```bash
cd apps/forja && flutter test test/provider_runtime_config_test.dart
# Manual: كرتون → سلاحف النينجا → green Play (not only Sources tap)
```

## Related

- [كرتون feature](../../features/hubs/cartoon.md)
- MovieBlast probe skip in `provider_runtime_config.dart`
