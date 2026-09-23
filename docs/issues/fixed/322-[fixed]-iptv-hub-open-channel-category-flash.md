# Issue 322: IPTV hub open flashes channels → clear → categories → channels

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV hub · PackLoadedPaint · category rail

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 7 / 7** fix · **0 / 1** acceptance |
| **Current slice** | First-group → selected land |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I322-T01 | Empty-grid placeholder only on real category/search flip — not initial epoch latch | ✅ |
| 2 | I322-T02 | Split `packChromeGridFlipEpoch` (no portal hydrate) from selection epoch | ✅ |
| 3 | I322-T03 | Category rail paints seed groups while store prefs load (no blank rail) | ✅ |
| 4 | I322-T04 | Peek last Live category for painter land + unit tests | ✅ |
| 5 | I322-T05 | Feed params / epoch use remembered cat (not LayoutScope first snap) | ✅ |
| 6 | I322-T06 | PackLoadedPaint hydrates last cat before first Live catalog_page | ✅ |
| 7 | I322-T07 | Soft land empty→remembered (no empty-grid); no painter first-group snap | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I322-A01 | Open IPTV hub: last selected category’s channels only — no first-group flash | ⬜ |

---

## Summary

**Symptom:** Opening the IPTV hub briefly showed the **first** category’s channels, then switched to the remembered/selected category.

**Root cause:** Painter snapped LayoutScope to the first portal group and painted that page before store land applied the last category. Warm-paint / empty-grid work (T01–T04) did not stop that first→selected flip.

**Root fix:** Remembered Live category drives feed params and epoch immediately; hydrate last category before the first Live `catalog_page`; do not painter-snap to first while land is pending; soft-land keeps warm paint (no clear) when going empty→remembered.
