# 379 — Hub hold-to-reload blanks Stremio (scroll dispose assert)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja` kit painter · shell navbar reload

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** fix · **0 / 2** acceptance |
| **Current slice** | Complete — manual QA pending |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I379-T01 | Stop `PackLayoutPainter.dispose` from setting `ShellBus.hubScrollOffsetFor` (tree-locked notify) | ✅ |
| 2 | I379-T02 | Reset hub scroll offset on mount (post-frame) instead | ✅ |
| 3 | I379-T03 | Hold-to-reload: `cancelCatalog` + `cancelLiveCatalog` before wipe/remount | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I379-A01 | Hold Stremio nav ~4s — no `widget tree was locked` / ValueListenableBuilder assert | ⬜ |
| 2 | I379-A02 | After reload toast, Stremio layout + rails paint again (not blank body) | ⬜ |

---

## Summary

Hold-to-reload remounts the open hub. `PackLayoutPainter.dispose` set `ShellBus.hubScrollOffsetFor(tab).value = 0`, notifying the still-mounted kit top-bar `ValueListenableBuilder` while `BuildOwner.finalizeTree` locks the tree → assert. At the same time, wiped caches left layout waiting behind a serial flutter_js queue of aborted rail work, so the hub stayed blank.

**Root fix:** never notify the shared scroll notifier from dispose; reset on the next mount post-frame. Abort catalog / live-catalog generations before wipe + remount so the new painter’s layout owns the queue.

### Related

- [375](./375-[fixed]-hub-keep-alive-keeps-fetching-off-tab.md) (cancel on hide)
- [363](../363-[open]-stremio-catalog-hub.md)
- [311](./311-[fixed]-pack-reload-eager-hub-refetch.md)
