# Issue 260: Host still hardcodes specific plugins

**Status:** open  
**Priority:** P0  
**Severity:** Critical  
**Area:** foundation / engine / packs  
**Rule:** [forja-plugins-community-owned](../../.cursor/rules/forja-plugins-community-owned.mdc)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 6** fix · **0 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I260-T01 | Live unlock: remove host streamed / ppv / watchfooty / GOAT API branches — opaque pack modules only | ✅ |
| 2 | I260-T02 | Delete official hub inventories (`official_forjahq_packs`, `officialPackIdForSlot` maps) — remote catalog / pack `id` only | ⬜ |
| 3 | I260-T03 | My List / follow: drop first-class `anilistId` / `kisskhId` / `my-list-hub` — opaque `open` + id bag | ⬜ |
| 4 | I260-T04 | Playback headers / ProviderRuntimeConfig: no Dart `if (kisskh|videasy|dimatoon)` — packs own knobs ([255](255-[open]-provider-runtime-config-builtins-debt.md)) | ⬜ |
| 5 | I260-T05 | Kit details: stop host `TmdbApi` rich enrich — pack enrich companions only | ⬜ |
| 6 | I260-T06 | Host tests: synthetic fixtures only — no `plugins/hubs/**` / `loadAllForjaHqPlugins` oracles | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I260-A01 | Grep host for shipped pack ids / hub folders finds zero behavioral branches | ⬜ |
| 2 | I260-A02 | Live resolve works with only pack JS + opaque `nativeUnlock` / module URLs | ⬜ |
| 3 | I260-A03 | Install / Features / rail work with zero “official” hub allowlist in Dart | ⬜ |
| 4 | I260-A04 | Host CI tests pass without reading repo `plugins/**` as inventory | ⬜ |

---

## Summary

Audit (2026-09-09): root app still points at specific plugins. Direction is inverted — packs must call generic host APIs; host must not know pack names.

**Invariant:** `plugins/` is community / temporary in-repo. `apps/forja` + `packages/rust` are foundation only.

### CRITICAL (behavior)

| Area | Worst files |
|------|-------------|
| Live unlock kinds | ~~Dart `resolveStreamed`/`resolvePpv`/`watchfooty` switch~~ **I260-T01 ✅** — pack JS + opaque `ctx.live.*` only. Residual: `withWftyPlaybackReferer` + `nativeUnlock` as resolveSource token |
| VOD provider branches | `provider_runtime_config.dart`, `player/screens/utils.dart`, `playback_stream_guards.dart` — kisskh / videasy / dimatoon / hianime |
| My List / open ids | `my_list_*.dart`, `legacy_list_item.dart`, `sources_request_context.dart`, rust `my_list_service.dart` — `anilistId` / `kisskhId` / `my-list-hub` |
| Host TMDB enrich | `kit_details_sections.dart`, `kit_details_screen.dart` |

### HIGH (inventories)

| Area | Worst files |
|------|-------------|
| Official pack list | `official_forjahq_packs.dart`, `models.dart` `officialPackIdForSlot` |
| Legacy pack ids | `plugin_registry.dart` `forjahq-hubs` |
| Pref / alias hub tabs | `shell_bus.dart` `iptv_sports`→`live_sports`, `kit_schedule_*` `live_sports_*` keys |
| Host tests as pack oracle | `catalog_protocol_test.dart`, `engine_test.dart`, `plugin_sdk_contract_test.dart` |

### MEDIUM

Player `mediaType == anime|asian_drama`, Simkl `anilistId`, chrome `tabId == 'home'`, rust provider profiles / display maps.

### OK-by-design (do not “fix” these into pack lists)

- `forjaHqSlot` opaque path segment
- `hostNavId` (author `tabId` / slot / `p_<hash>`) — no slot map
- Empty `PlatformDefaults` / `seedBuiltIns`
- Pack kind buckets: providers / live / catalog / hubs (tree shape)
- `open.surface` host routes (still must not imply pack inventory)

### Related

- [255](255-[open]-provider-runtime-config-builtins-debt.md) — ProviderRuntimeConfig builtins slice
- [forja-plugins-community-owned](../../.cursor/rules/forja-plugins-community-owned.mdc)
- [forja-external-plugins-host](../../.cursor/rules/forja-external-plugins-host.mdc)
- [catalog-hub-host-generic](../../.cursor/rules/catalog-hub-host-generic.mdc)
- [forja-host-tests-no-pack-contracts](../../.cursor/rules/forja-host-tests-no-pack-contracts.mdc)
