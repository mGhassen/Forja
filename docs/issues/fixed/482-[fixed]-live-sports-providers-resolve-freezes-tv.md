# 482 — Live Sports Providers resolve freezes Android TV

**Status:** fixed  
**Priority:** P0  
**Severity:** Critical  
**Area:** Android TV · Live Sports · Providers · flutter_js · EngineJS  
**Reported:** 2026-10-25 (physical Android TV — OK on match freezes until streams or crash)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

OK on a Live Sports match starts Providers resolve. UI freezes (sometimes ANR / crash). Waiting a long time without input eventually shows streams. Progressive paint felt broken.

## Root cause

1. EngineJS discover empty → flutter_js fallback on the **UI isolate**, serialized (`_liveResolveMaxParallel = 1` + global JSC queue). Empty packs burned multi-second JSC each (log: `bzhsport` ~3.9s) before useful packs painted.
2. Schedule catalog scrapes held the same flutter_js queue while Providers ran.
3. Fan-out did not prioritize packs that own the card `sources[]`, so first mirrors arrived late.

`onPartial` already existed — frames could not flush while JSC blocked the isolate.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I482-T01 | Skip flutter_js for Providers **discover** when EngineJS already returned empty; skip flutter_js discover entirely on Android TV when EngineJS unsupported | ✅ |
| 2 | I482-T02 | `cancelLiveCatalog` when opening Providers so schedule JSC releases the queue | ✅ |
| 3 | I482-T03 | Owned `sources[]` packs resolve first + publish/`Duration.zero` yield before fixture fan-out | ✅ |
| 4 | I482-T04 | 3s discover timeout on `runLivePlugin` (slot releases) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I482-A01 | Android TV: OK a match → Providers shows first mirrors within a few seconds without UI freeze | ⬜ |
| 2 | I482-A02 | Later packs still append rows; unlock-on-play still uses flutter_js when needed | ⬜ |

## Links

- [237](237-[fixed]-live-sports-catalog-resolve-jsc-crash.md) — JSC queue / SIGSEGV
- [270](270-[fixed]-live-providers-resolve-empty-regression.md) — Providers discover contract
- Feature: [live-sports](../../features/live/live-sports.md)
