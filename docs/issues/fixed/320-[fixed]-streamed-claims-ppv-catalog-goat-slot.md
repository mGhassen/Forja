# 320 — Streamed invents dead embed.st/ppv/{eventId} from PPV catalog handoff

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Streamed · PPV · GOAT unlock  
**Reported:** 2026-09-23  
**Related:** [254](254-[fixed]-live-catalog-schedule-only-no-streams.md) · [270](270-[fixed]-live-providers-resolve-empty-regression.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I320-T01 | Drop `ppv` from Streamed `ownedSources` + `isGoatSource` (PPV catalog opaque key ≠ embed.st goat) | ✅ |
| 2 | I320-T02 | PPV pack declares `ownedSources: ["ppv"]` so host routes event ids to PPV resolve | ✅ |
| 3 | I320-T03 | Refresh embed.st `lock.wasm` + `lock-esm.mjs` in livesports goat vendor | ✅ |
| 4 | I320-T04 | Changelog — PPV play no longer dies on invented Streamed goat row | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I320-A01 | Manual: open PPV Contender Series (or similar); Providers lists PPV embedindia (and Streamed delta/hotel via soft-match), not `embed.st/embed/ppv/{numericId}/1`; play unlocks native HLS | ⬜ |

---

## Summary

**Symptom:** Playing a PPV catalog event (e.g. id `29188`) ran GOAT unlock on `ppv/29188/1`. Node wasm OOBed; WebView `set_stream_jw` settled with no m3u8 → `goat unlock failed`.

**Root:** PPV catalog emits opaque `sources: [{ source: "ppv", id: "<eventId>" }]`. Streamed claimed `ownedSources` including `ppv`, then `listStreamsForSlot` invented `https://embed.st/embed/ppv/{eventId}/1` when `/api/stream/ppv/…` was empty. That body is a decoy — crack always fails. Real PPV mirrors are embedindia (GASM); Streamed’s live goat kinds are `admin` / `delta` / `golf` / `bravo` (slug ids), not numeric PPV event ids.

**Fix:** Stop Streamed owning / inventing `ppv` goat slots; give PPV `ownedSources: ["ppv"]`; refresh GOAT wasm/glue so real Streamed admin/delta cracks stay current.
