# 526 — Hub mouse wheel steals horizontal rail

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** foundation · HorizontalScroller · desktop hubs  
**Reported:** 2026-11-02 (hub vertical scroll over a rail)

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On desktop hubs, scrolling with a **mouse wheel** over a horizontal poster/event rail remapped vertical delta onto the rail, so the page stopped scrolling vertically. Trackpad remap was intentional and should stay.

## Root cause

`HorizontalScroller._onPointerSignal` claimed every `PointerScrollEvent` with non-zero `dy` (including `PointerDeviceKind.mouse`) and applied it as horizontal strip scroll.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I526-T01 | Claim vertical→horizontal remap only for `PointerDeviceKind.trackpad` | ✅ |
| 2 | I526-T02 | Foundation widget test: mouse keeps page scroll; trackpad moves strip | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I526-A01 | macOS: mouse wheel over a Home rail scrolls the page vertically | ⬜ |
| 2 | I526-A02 | macOS: trackpad two-finger scroll over a rail still pans the strip | ⬜ |

## Links

- Widget: `packages/forja_foundation/lib/widgets/chrome/horizontal_scroller.dart`
