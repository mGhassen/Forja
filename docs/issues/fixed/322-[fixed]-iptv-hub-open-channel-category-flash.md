# Issue 322: IPTV hub open flashes channels → clear → categories → channels

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · PackLoadedPaint · category rail

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |
| **Current slice** | Hub-open warm paint |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I322-T01 | Empty-grid placeholder only on real category/search flip — not initial epoch latch | ✅ |
| 2 | I322-T02 | Split `packChromeGridFlipEpoch` (no portal hydrate) from selection epoch | ✅ |
| 3 | I322-T03 | Category rail paints seed groups while store prefs load (no blank rail) | ✅ |
| 4 | I322-T04 | Peek last Live category for painter land + unit tests | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I322-A01 | Open IPTV hub (warm): channels + categories stay; no clear/reshow flash | ⬜ |

---

## Summary

**Symptom:** Opening the IPTV hub briefly showed channels, cleared the grid, showed categories, then reshowed channels (very fast).

**Root cause:** Warm-restored channel paint was wiped by the IPTV empty-grid placeholder on the first selection-epoch latch (meant for mid-session category flips). Portal prefs hydrate and a blank category rail while the store loaded made the flash obvious.

**Root fix:** Keep warm channels on the initial latch and on portal-key-only epoch changes; paint category seeds immediately; land from in-memory last category when available.
