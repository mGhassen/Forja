# Issue 255: ProviderRuntimeConfig Dart builtins debt

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** playback / engine / packs  
**Parent:** [RFC-100](../rfc/fixed/100-[fixed]-admin-plugin-catalog-bundles.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I255-T01 | Inventory remaining `ProviderRuntimeConfig` builtins + call sites | ✅ |
| 2 | I255-T02 | Move host/path overlays that still matter into pack JS / manifest | ✅ |
| 3 | I255-T03 | Move playback Referer / anime probe profiles off Dart builtins | ✅ |
| 4 | I255-T04 | Delete remote-table read path leftovers + unused tests | ✅ |
| 5 | I255-T05 | Remove or shrink `ProviderRuntimeConfig` class when empty | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I255-A01 | No Dart builtins for provider hosts/paths that packs already own | ✅ |
| 2 | I255-A02 | Playback still works for VOD / anime / drama without remote overlay | ⬜ |

---

## Summary

RFC-100 retires the **admin** Providers UI and stops **remote** `provider_runtime_config` fetch. The Dart builtin catalog (templates, APIs, Megaplay, KissKh mirrors, CDN referers, anime playback profiles) is gone.

Playback headers are the headers on the stream row. Probe and PNG-strip are optional pack fields (`probe`, `pngStrip`). Rust `set_provider_runtime_overlay` is no longer called from the app.

**Not verified:** on-device playback (I255-A02).

## Related

- [RFC-039](../rfc/fixed/039-[fixed]-remote-provider-runtime-config.md)
- [RFC-100](../rfc/fixed/100-[fixed]-admin-plugin-catalog-bundles.md)
- [`provider_runtime_config.dart`](../../apps/forja/lib/shared/playback/sources/provider_runtime_config.dart)
