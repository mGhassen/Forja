# Issue 255: ProviderRuntimeConfig Dart builtins debt

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** playback / engine / packs  
**Parent:** [RFC-100](../rfc/100-[open]-admin-plugin-catalog-bundles.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I255-T01 | Inventory remaining `ProviderRuntimeConfig` builtins + call sites | ⬜ |
| 2 | I255-T02 | Move host/path overlays that still matter into pack JS / manifest | ⬜ |
| 3 | I255-T03 | Move playback Referer / anime probe profiles off Dart builtins | ⬜ |
| 4 | I255-T04 | Delete remote-table read path leftovers + unused tests | ⬜ |
| 5 | I255-T05 | Remove or shrink `ProviderRuntimeConfig` class when empty | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I255-A01 | No Dart builtins for provider hosts/paths that packs already own | ⬜ |
| 2 | I255-A02 | Playback still works for VOD / anime / drama without remote overlay | ⬜ |

---

## Summary

RFC-100 retires the **admin** Providers UI and stops **remote** `provider_runtime_config` fetch. Dart still ships large **builtins** (templates, APIs, Megaplay, KissKh mirrors, CDN referers, anime playback profiles) used by extract/playback.

**Root fix:** move remaining knobs into packs (or drop them), then delete the class.  
**Not a workaround:** remote ops UI is already gone; this issue tracks the leftover host debt.

## Related

- [RFC-039](../rfc/fixed/039-[fixed]-remote-provider-runtime-config.md)
- [RFC-100](../rfc/100-[open]-admin-plugin-catalog-bundles.md)
- [`provider_runtime_config.dart`](../../apps/forja/lib/shared/playback/sources/provider_runtime_config.dart)
