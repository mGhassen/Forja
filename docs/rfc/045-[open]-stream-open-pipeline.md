# RFC-045: Stream open pipeline middleware

**Status:** open  
**Depends on:** [RFC-044](044-[open]-provider-identity-playback.md), [RFC-039](fixed/039-[fixed]-remote-provider-runtime-config.md)  
**Area:** playback — open path (identity, classify, technique, observe)

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** components · **6 / 8** acceptance · **0 / 2** manual smoke |
| **Current slice** | Code shipped — Megaplay / plain HLS / Miruro smoke not run |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R45-C01 | `StreamMediaClassifier` — byte classes `plainMedia` / `pngWrapTs` / `imageNoTs` / `httpBlocked` / `unknown` | ✅ |
| 2 | R45-C02 | `StreamOpenPipeline` Stage 1 identity via `resolvePlaybackHttpHeaders` + `providerId` | ✅ |
| 3 | R45-C03 | Stage 2 classify + Stage 3 technique graph (`openDirect` / `openPngStrip`) | ✅ |
| 4 | R45-C04 | Stage 4 open once + Stage 5 observe-only confirm | ✅ |
| 5 | R45-C05 | Stage 6 report / re-branch; exhaust → next source | ✅ |
| 6 | R45-C06 | Desktop + mobile open loops call pipeline only (no dual probe+tree) | ✅ |

---

## Acceptance (pipeline)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R45-A01 | Unit: PNG+TS fixture → `pngWrapTs`; PNG without TS → `imageNoTs`; TS sync → `plainMedia` | ✅ |
| 2 | R45-A02 | Unit: `pngWrapTs` → strip first; open fail → direct | ✅ |
| 3 | R45-A03 | Unit: `plainMedia` → direct first; fail → strip | ✅ |
| 4 | R45-A04 | Unit: `imageNoTs` / `httpBlocked` exhaust without open | ✅ |
| 5 | R45-A05 | Unit: strip proxy unavailable → techniqueUnavailable (no silent catalog) | ✅ |
| 6 | R45-A06 | Confirm observe-only — no hwdec reopen inside confirm | ✅ |
| 7 | R45-A07 | Manual: Megaplay kotocdn plays via strip | ⬜ |
| 8 | R45-A08 | Manual: plain HLS direct; new CDN host under megaplay Referer still works | ⬜ |

---

## Manual smoke checklist

| Check | How | Pass when |
|-------|-----|-----------|
| Megaplay kotocdn strip | Play Megaplay episode whose segments are PNG+TS (kotocdn / ibyteimg-style) | `[OpenPipeline] branch → openPngStrip`; video frame; panel row stays catalog URL |
| Miruro `imageNoTs` | Play Miruro source that classifies image-only segments | Pipeline exhausts that source fast; next server tried — no black player claim |
| Plain HLS direct | Play plain non-PNG HLS under Megaplay / VidNest | `[OpenPipeline] branch → openDirect`; plays without strip proxy |
| New CDN + identity | Same Megaplay provider, renamed CDN host | Referer/Origin still megaplay embed origin; plays without code change |

---

## Summary

RFC-044’s `StreamOpenMindTree` only chose strip vs direct. Probe, identity headers, and confirm lived elsewhere and fought each other.

**Contract:** one **`StreamOpenPipeline`** owns open: identity → classify (bytes, never “hostname ⇒ not episode”) → technique → open once → observe → re-branch or exhaust. New CDN under a known `providerId` needs no allowlist. Class labels are structural (`pngWrapTs`, `imageNoTs`), not “ad/poison episode.”

**Out of scope:** Miruro CF unlock, extract race, admin registry editor.

### Related

- [RFC-044](044-[open]-provider-identity-playback.md) — R44-C11 mind-tree superseded by this RFC for open branching
- [anime hub](../features/hubs/anime.md)
