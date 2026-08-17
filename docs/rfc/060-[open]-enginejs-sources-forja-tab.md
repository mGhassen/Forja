# RFC-060: engineJS + Sources Forja tab

**Status:** open  
**Depends on:** [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md) (Videasy HTTP hosts stay in-app)  
**Area:** `apps/forja/lib/shared/engine_js/`, `apps/forja/assets/providers/`, Sources portal, Settings Playback

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **11 / 12** acceptance |
| **Current slice** | Bundled HTTP pack (Videasy + Vidlink + Vixsrc + DooFlix + YFlix) — manual smoke pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R60-C01 | `EngineJsRuntime` — own flutter_js heap, `fetch`, `streamcrypto`, `extract(ctx)` | ✅ |
| 2 | R60-C02 | `EngineJsService` — bundled Videasy pack, `engine.json` install, enabled flags | ✅ |
| 3 | R60-C03 | Sources kind `engine` labeled **Forja** (details + in-player) | ✅ |
| 4 | R60-C04 | Play source `play_source_engine_enabled` + Settings Forja plugins | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R60-A01 | Green Play / Tries / Server reliability unchanged — no `engine:*` ids | ✅ |
| 2 | R60-A02 | Sources portal shows **Forja** tab when the Forja play source is on | ✅ |
| 3 | R60-A03 | Kind id is `engine` (not `forja`); Torrents All still accepts legacy `forja` chip | ✅ |
| 4 | R60-A04 | Bundled Videasy `extract.js` uses `ctx.fetch` + `ctx.streamcrypto.decrypt` | ✅ |
| 5 | R60-A05 | Forja tab drops magnet / `.torrent` URLs | ✅ |
| 6 | R60-A06 | `nuvio_runtime.dart` and Dart `VideasyExtractor` not used by engineJS | ✅ |
| 7 | R60-A07 | Unit tests: pack parse, chip ids, kind filter Forja, Torrents `forja` All alias | ✅ |
| 8 | R60-A08 | Feature docs + changelog | ✅ |
| 9 | R60-A09 | Manual: open Sources → Forja, Videasy rows play HTTP | ⬜ |
| 10 | R60-A10 | Bundled Videasy `Promise.all`s every player.videasy.to Servers mirror (Yoru…Raze), not `cdn` only | ✅ |
| 11 | R60-A11 | Forja Videasy HTTP open stamps `player.videasy.to` Referer (`headers` + `engine:videasy` policy) | ✅ |
| 12 | R60-A12 | Bundled pack ships Vidlink, Vixsrc, DooFlix, YFlix HTTP plugins (`extract(ctx)`) | ✅ |

---

## Summary

Parallel plugin stack next to Nuvio and green Play. engineJS is the host (`extract(ctx)` + `engine.json`). The Sources portal gets a fourth kind tab labeled **Forja**. Builtin Dart extractors and green Play stay as they are.

## Contract

`engine.json` is a pack (one or more plugins) or a single plugin at the root. JS entry exports `extract(ctx)` (or `globalThis.extract`). Host injects `tmdbId`, `type`, `season`, `episode`, `title`, `year`, `fetch`, `streamcrypto.decrypt`.

Kind `http` only in this slice. Play ids: `engine:<pluginId>`.

## Related

- Green Play: [RFC-004](004-[partial]-provider-registry.md) — untouched
- Nuvio Sources tab: stays — this RFC does not share that VM
