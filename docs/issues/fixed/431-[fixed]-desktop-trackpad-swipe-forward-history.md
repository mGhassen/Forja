# 431 — Desktop trackpad swipe-forward history

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `apps/forja/lib/shared/navigation/` — desktop trackpad Back/Forward  
**Reported:** 2026-10-14  
**Fixed:** 2026-10-14  
**Related:** [141](../141-[open]-desktop-trackpad-swipe-steals-horizontal-scroll.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **5 / 5** fix · **0 / 3** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I431-T01 | `ShellHistoryPageRoute` + `ShellNavHistory` LIFO forward stack | ✅ |
| 2 | I431-T02 | Overlay observer: stash on pop, clear on new push / pop-to-root | ✅ |
| 3 | I431-T03 | Trackpad swipe-left progressive right-edge forward indicator | ✅ |
| 4 | I431-T04 | Mouse forward side button → `shellNavGoForward` | ✅ |
| 5 | I431-T05 | Player leave never enters forward stack | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I431-A01 | Desktop: details → Back → swipe-left reopens same details | ⬜ |
| 2 | I431-A02 | Desktop: details → Search → Back → Forward restores Search; open a new title clears Forward | ⬜ |
| 3 | I431-A03 | Desktop: leave player → swipe-left does not resurrect player | ⬜ |

---

## Summary

Desktop had progressive trackpad **Back** (swipe-right) but no browser-style **Forward**. After leaving details or Search, there was no way to restore that overlay with a trackpad swipe.

## Root cause

`BackNavigationScope` only armed positive `panDelta.dx` (Back). Overlay pops discarded the route with no reopen factory.

## Fix approach

`slideShellRoute` returns `ShellHistoryPageRoute` (keeps `WidgetBuilder`). Overlay observer pushes entries onto `ShellNavHistory` on pop and clears on new user push / `popShellOverlayUntilRoot`. Swipe-left fills a right-edge chevron; full fill calls `shellNavGoForward`. Player routes stay on the root navigator and are never recorded.

**Non-goals:** re-open player after Back; phone/TV; nested tab-stack routes that bypass `pushShellRoute`.
