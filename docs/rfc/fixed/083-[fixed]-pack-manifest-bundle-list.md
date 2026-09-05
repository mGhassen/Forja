# RFC-083: Pack manifest bundle file list

**Status:** fixed  
**Depends on:** [RFC-068](068-[fixed]-engine-plugin-registry.md)  
**Area:** `PluginRegistry.install`, pack `manifest.json` `bundle`, Settings → Forja Packs

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **6 / 6** acceptance |
| **Current slice** | Manifest `bundle` lists files; install downloads those paths |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R83-C01 | Manifest `bundle: string[]` + EnginePack + schema | ✅ |
| 2 | R83-C02 | Host install fetches every listed path (concurrent), maps to entry/prelude | ✅ |
| 3 | R83-C03 | Feature docs + changelog + SDK notes (no zip / no CDN) | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R83-A01 | `bundle` is a list of pack-relative file paths in `manifest.json` | ✅ |
| 2 | R83-A02 | Install downloads all listed files; empty `bundle` derives from entry/prelude | ✅ |
| 3 | R83-A03 | Missing listed/needed file → transactional fail | ✅ |
| 4 | R83-A04 | No pack zip / no Forja CDN pack hosting | ✅ |
| 5 | R83-A05 | Official packs ship `bundle` file lists | ✅ |
| 6 | R83-A06 | Unit tests cover bundle list install | ✅ |

---

## Summary

A pack is still one **`manifest.json` URL**. Optional **`bundle`** lists the pack-relative script files to download. The host fetches that set, then maps `plugins[].entry` / preludes onto the downloaded bodies. No zip, no second pack format, no app CDN for plugins.

### Related

- [RFC-068](068-[fixed]-engine-plugin-registry.md)
- [plugins/README.md](../../plugins/README.md)
