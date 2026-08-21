# 191 — Hub Sources panel stuck after nav tab switch

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** shell overlay · Asian Drama / Anime hub details · `PlayerSourcesPanel`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I191-T01 | Dismiss hub `PlayerSourcesPanel` / torrent-file overlay before `popShellOverlayUntilRoot` | ✅ |
| 2 | I191-T02 | Dismiss the same overlays when shell overlay stack returns to root (back) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I191-A01 | Asian Drama details → open Sources → tap Anime nav — panel gone, Anime hub interactive | ✅ |
| 2 | I191-A02 | Same flow via system/back until details pops — panel gone (manual) | ⬜ |

---

## Summary

Opening catalog Sources from Asian Drama / Anime hub details uses `PlayerSourcesPanel.show()`, which inserts an `OverlayEntry` into the **shell overlay navigator’s** `Overlay`. Switching navbar tabs only called `popShellOverlayUntilRoot()` (details route gone). The entry stayed. With no overlay page, `IgnorePointer(ignoring: true)` wraps that navigator — panel still painted, close/scrim taps ignored.

**Root fix:** `dismissShellOverlaySourcePanels()` on pop-to-root (before pop) and when the overlay stack syncs to empty.
