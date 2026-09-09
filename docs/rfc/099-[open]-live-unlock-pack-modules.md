# RFC-099: Live unlock modules live in packs

**Status:** open  
**Depends on:** [RFC-065](065-[open]-live-forja-scrapers.md) · [RFC-083](fixed/083-[fixed]-pack-manifest-bundle-list.md)  
**Area:** `plugins/live/`, `LiveGoatUnlock`, `PluginScriptDiskStore`, pack install

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 9** acceptance |
| **Current slice** | Pack JS owns resolve; host is opaque crack runtime only ([260](../issues/260-[open]-host-hardcodes-specific-plugins.md) I260-T01) · smoke ⬜ |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R99-C01 | Pack-relative binary/text files on install (`engine/<hash>/files/…`) | ✅ |
| 2 | R99-C02 | `plugins/live/{goat,gasm,sportsembed}/` + manifest `bundle` | ✅ |
| 3 | R99-C03 | Host unlock runner loads modules from pack (Flutter assets fallback) | ✅ |
| 4 | R99-C04 | SDK + feature + changelog | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R99-A01 | Install fetches non-JS bundle paths as bytes into `files/<rel>` | ✅ |
| 2 | R99-A02 | Local checkout resolves unlock files next to `plugins/live/manifest.json` | ✅ |
| 3 | R99-A03 | Desktop Node GOAT/GASM/sportsembed refresh from pack modules | ✅ |
| 4 | R99-A04 | Mobile/ATV WebView crack+wasm refresh from pack modules | ✅ |
| 5 | R99-A05 | Missing pack module falls back to bundled Flutter assets | ✅ |
| 6 | R99-A06 | Live pack version bump + catalog regenerate if needed | ✅ |
| 7 | R99-A07 | Host tests: pack file store + resolve (synthetic paths, no shipped ids as contracts) | ✅ |
| 8 | R99-A08 | Feature doc / SDK note: host runtime vs pack unlock modules | ✅ |
| 9 | R99-A09 | Manual: Streamed admin + PPV embedindia unlock after pack Reload (desktop) | ⬜ |

---

## Summary

GOAT / GASM / sportsembed **crack algorithms and WASM** live in the **live pack** (`plugins/live/goat|gasm|sportsembed`). Pack JS owns `/fetch` + resolve (`streamed.js` / `ppv.js` / `watchfooty.js` + `embed-st.js`). The Flutter host keeps only the opaque unlock **runtime** (Node + happy-dom, off-screen WebView, serialize cracks) and bridges (`ctx.live.goatUnlock` / `gasmUnlock` / `sportsEmbedUnlock`).

Do **not** put streamed/ppv/watchfooty resolve switches back in Dart ([260](../issues/260-[open]-host-hardcodes-specific-plugins.md) I260-T01).

Pack update can ship a new `lock.wasm` / `unlock.mjs` without an app release. App release only when the host runner contract changes.

### Contract

| Layer | Owns |
|-------|------|
| Host | Node/WebView runner, npm once, WebView crack protocol, opaque `ctx.live.*` bridges |
| Pack | `goat/`, `gasm/`, `sportsembed/` trees listed in `bundle`; `/fetch` + resolve JS |
| Plugin JS | Slot parse, CDN probe, headers, `directPlayback`, call `ctx.live.*` |

### Related

- [RFC-065](065-[open]-live-forja-scrapers.md)
- [Issue 203](../issues/203-[open]-android-tv-goat-webview-unlock.md)
- [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) — C3/C5 host adapters stay in app
