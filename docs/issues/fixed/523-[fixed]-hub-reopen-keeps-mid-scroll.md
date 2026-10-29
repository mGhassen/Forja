# 523 — Hub reopen lands mid-page (kept scroll)

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** shell · kit hub painter · keep-alive scroll

**Reported:** 2026-10-29 (phone hub tab switch)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** fix · **1 / 1** acceptance |
| **Current slice** | Complete |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Switch away from a scrolled hub and back — page opens mid-list instead of at the top.

## Root cause

`ShellBody` keeps hub tabs with `Visibility(maintainState: true)`; `PackLayoutPainter` keeps a long-lived `ScrollController`. `onShellTabShown` did not reset offset (keep-alive by design for paint/fetch — scroll restore was an unintended side effect).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I523-T01 | On tab return (`!shellTabVisible` → shown), `jumpTo(0)` + clear `ShellBus.hubScrollOffsetFor` — leave same-tab shown alone | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I523-A01 | Leave a scrolled hub, open another tab, return — lands at top; closing details via same-tab tap keeps scroll | ✅ |

## Links

- [375](375-[fixed]-hub-keep-alive-keeps-fetching-off-tab.md) — keep-alive fetch gate (paint retained; scroll now resets on return)
- RFC-024 tab cache / keep-alive
