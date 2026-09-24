# 360 — IPTV Add/Edit portal dialog uses TV shrink on desktop

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** IPTV · Portals · desktop layout · leanback density

**Related:** [tv_focus.dart](../../../apps/forja/lib/shared/player/live/tv_focus.dart) (`liveUseTvFocus` vs leanback density)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2/2** tasks · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I360-T01 | Gate portal dialog layout (width, pads, type, share-code cells, tab height) on `ShellMetrics.usesTvDensity`, not `liveUseTvFocus` | ✅ |
| 2 | I360-T02 | Keep `liveUseTvFocus` for D-pad / focus graph only (tabs, fields, expand toggle) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I360-A01 | Desktop: Add / Edit portal dialog uses desktop width (~440) and desktop share-code / field sizing | ⬜ |
| 2 | I360-A02 | Android TV: same dialog still uses leanback shrink (width ~320, dense cells / type) | ⬜ |

---

## Summary

Sep 22 leanback density tokens correctly shrunk the portal dialog for TV (`shareCodeDialogWidthTv` 320, smaller share-code cells). Layout was gated on `_tv => liveUseTvFocus(context)`. Desktop hybrid also sets `useFocusableMoodChips`, so `liveUseTvFocus` is true on desktop — the TV shrink applied there too.

**Root fix:** layout density uses `ShellScope.metricsOf(context).usesTvDensity`. Focus registration and D-pad edges stay on `liveUseTvFocus`.
