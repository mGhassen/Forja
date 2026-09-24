# RFC-118: Pack-owned green Play (multi-tech race)

**Status:** open  
**Depends on:** [RFC-089](fixed/089-[fixed]-pack-addon-settings.md) · [RFC-063](fixed/063-[fixed]-forja-auto-start-green-play.md) · [RFC-109](109-[open]-forja-pack-product-host.md)  
**Area:** pack settings, green Play, `shared/playback/open/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Schema + Settings UI + multi-tech race + hub defaults shipped |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R118-C01 | `PackGreenPlayConfig` parse + store overlay + host fallback | ✅ |
| 2 | R118-C02 | Addon Settings **Green Play** UI (tech + providers allowlist / preferred / order) | ✅ |
| 3 | R118-C03 | Green Play race respects pack engine allowlist / preferred / order | ✅ |
| 4 | R118-C04 | Multi-tech race adapters (stremio / nuvio / torrent) + pack hub defaults | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R118-A01 | Hub without `settings.greenPlay` races all enabled Forja plugins (fallback) | ✅ |
| 2 | R118-A02 | Hub with `greenPlay` defaults loads from manifest when store empty | ✅ |
| 3 | R118-A03 | User overlay in pack store overrides manifest defaults | ✅ |
| 4 | R118-A04 | Settings → Addons → hub shows Green Play when pack declares block | ✅ |
| 5 | R118-A05 | Empty provider allowlist = all enabled providers for that tech | ✅ |
| 6 | R118-A06 | Preferred providers pin first; order sets start order; first playable wins | ✅ |
| 7 | R118-A07 | Multi-tech race includes only play-source-gated techs | ✅ |
| 8 | R118-A08 | Sources chips stay panel-only (do not narrow green Play) | ✅ |

---

## Summary

Green Play is pack-owned: each hub declares `settings.greenPlay` (technologies + per-tech providers: allowlist, preferred, order). Users edit under that hub’s Addon settings. Undeclared packs keep today’s Forja-only race of all enabled HTTP plugins.

### Goals

- Multi-tech race: `engine` · `stremio` · `nuvio` · `torrent`
- Parallel race; preferred pin; order = start order
- Host stays generic (opaque tech ids; no hub pack-id branches)

### Non-goals

- Sources panel chips driving green Play
- Host Playback provider-order UI
- Webstreaming sniff restore

### Related

- Issue [366](../issues/366-[open]-pack-green-play.md)
- [RFC-089](fixed/089-[fixed]-pack-addon-settings.md)
