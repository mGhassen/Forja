# 466 — Details SUB/DUB menu: ghost pill + oversized TV text

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · details hero · stream languages  
**Reported:** 2026-10-23 (manual details hero)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. Opening the details hero **SUB** / **DUB** language menu painted a **second**, larger SUB|DUB pill next to the real one (different count label).
2. Menu row text (All SUB / VOST / …) was desktop-sized — not the TV body ladder.

## Root cause

1. Menu used [CompositedTransformFollower] under the hero action-row [FittedBox]. Leader/follower + scale-down left a full-size ghost of the pill in the overlay.
2. Menu rows hardcoded 13–14px and skipped [ShellPaintScope] / [ShellTokens.tvBodyFontSize] (My List rows already use the TV ladder).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I466-T01 | Position menu with `localToGlobal` + `Positioned` (no LayerLink follower) | ✅ |
| 2 | I466-T02 | Rehost [ShellPaintScope]; menu row type/padding/icons via TV chrome tokens | ✅ |
| 3 | I466-T03 | Defer overlay `markNeedsBuild` post-frame (sync call asserted mid-build on select) | ✅ |
| 4 | I466-T04 | Clamp menu max height to remaining viewport above/below anchor | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I466-A01 | ATV details: open SUB/DUB — one pill only; menu text matches My List / meta scale | ⬜ |
| 2 | I466-A02 | Desktop: open/toggle languages; no ghost pill; menu still readable | ⬜ |

## Links

- [462](462-[fixed]-details-hero-sub-dub-dpad.md) — Overlay + D-pad (regression on follower + FittedBox)
- [425](../425-[open]-home-stream-language-filter.md) — stream language multiselect
