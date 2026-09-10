# RFC-099: Live unlock modules live in packs

**Status:** open  
**Depends on:** [RFC-065](065-[open]-live-forja-scrapers.md) · [RFC-083](fixed/083-[fixed]-pack-manifest-bundle-list.md)  
**Area:** `plugins/live/`, `LiveGoatUnlock`, `PluginScriptDiskStore`, pack install

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **12 / 13** acceptance |
| **Current slice** | Opaque `runUnlock` + pack sugar ([260](../issues/260-[open]-host-hardcodes-specific-plugins.md)) · A09 smoke ⬜ |

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

## Acceptance (opaque runner)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 10 | R99-A10 | Host exposes only `ctx.live.runUnlock` — no goat/gasm/sportsembed bridge names in Dart injection | ✅ |
| 11 | R99-A11 | Pack prelude installs goatUnlock/gasmUnlock/sportsEmbedUnlock sugar + recipe `files[]` | ✅ |
| 12 | R99-A12 | Unlock files resolve via calling `packSourceUrl` + relative paths (no goat bundle discovery) | ✅ |
| 13 | R99-A13 | Host playback path does not hardcode sportsembed/wfty Referer — pack resolve owns headers | ✅ |

---

## Summary

GOAT / GASM / sportsembed **crack algorithms and WASM** live in the pack. Pack JS owns `/fetch` + resolve + unlock sugar (`ensureLiveUnlockApi` → `goatUnlock` / … via `files[]`). The Flutter host keeps only the opaque unlock **runtime** (`ctx.live.runUnlock` → Node / WebView) and stages pack-relative files from the **calling** pack.

Do **not** put streamed/ppv/watchfooty resolve switches back in Dart ([260](../issues/260-[open]-host-hardcodes-specific-plugins.md) I260-T01).

Pack update can ship a new `lock.wasm` / `unlock.mjs` without an app release. App release only when the host runner contract changes.

### Contract

| Layer | Owns |
|-------|------|
| Host | Node/WebView runner, npm once, WebView crack protocol, opaque `ctx.live.runUnlock` |
| Pack | Unlock trees in `bundle`; `/fetch` + resolve JS; sugar APIs + recipe `files[]` |
| Plugin JS | Slot parse, CDN probe, headers, `directPlayback`, call pack sugar / `runUnlock` |

### Related

- [RFC-065](065-[open]-live-forja-scrapers.md)
- [Issue 203](../issues/203-[open]-android-tv-goat-webview-unlock.md)
- [ENGINE_BOUNDARY](../ENGINE_BOUNDARY.md) — C3/C5 host adapters stay in app
