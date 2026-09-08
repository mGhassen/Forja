# 242 — Live Sports Cards category bar / grid flash on feed reload

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports Cards · `KitCategoryBar` · `MetaFeedListSource`  
**Reported:** 2026-09-08  
**Related:** [238](238-[fixed]-live-sports-riverpod-build-stutter.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I242-T01 | `MetaFeedListSource` watch/read/listen: remap feed AsyncValue with `skipLoadingOnReload` / `skipLoadingOnRefresh` so previous page survives invalidate | ✅ |
| 2 | I242-T02 | `KitCategoryBar`: ignore null page on listen (keep last kinds); do not collapse bar during reload | ✅ |
| 3 | I242-T03 | Live Sports / Cards packs: static `All` category item so bar reserves height before first feed | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I242-A01 | Manual: open Live Sports Cards — category bar stays put while schedule loads/reloads; cards do not jump into the bar slot or flash empty skeletons over chrome | ⬜ |

---

## Summary

**Symptom:** Live Sports Cards grid stuttered — empty skeletons flashed and looked like they painted over the sport category bar.

**Root cause:** `MetaFeedListSource` remapped `metaFeedCatalogProvider` through bare `AsyncLoading.new`, dropping Riverpod’s previous value on every filter hydrate / invalidate. `KitListWidget` then showed the loading skeleton. `KitCategoryBar.listenPage` received null `asData` and cleared `_dynamicPage`; with no static items the bar returned `SizedBox.shrink()`, so the `Expanded` list jumped into that gap.

**Fix:** Preserve previous feed page when remapping; keep last category kinds on reload; seed pack category bar with static `All`.
