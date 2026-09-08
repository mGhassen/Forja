# 238 — Live Sports schedule stutter (Riverpod mutate during build)

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · `KitListWidget` · `metaFeedCatalogProvider`  
**Reported:** 2026-09-08  
**Related:** [236](236-[fixed]-live-sports-feed-empty-enginejs.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I238-T01 | `KitListWidget.didUpdateWidget`: defer `invalidateOnRefresh` to post-frame | ✅ |
| 2 | I238-T02 | `metaFeedCatalogProvider`: clear `metaFeedForceRefreshProvider` after first await | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I238-A01 | Manual: open Live Sports / change Schedule or Refresh — grid fills without skeleton stutter; no Riverpod “modify during build” / “modify during init” asserts | ⬜ |

---

## Summary

**Symptom:** Live Sports stayed on empty skeletons and felt stuttery. Console:

- `Tried to modify a provider while the widget tree was building` from `MetaFeedListSource.invalidateOnRefresh` ← `KitListWidget.didUpdateWidget`
- `Providers are not allowed to modify other providers during their initialization` — `metaFeedCatalogProvider` clearing `metaFeedForceRefreshProvider` in sync create

**Root cause:** Refresh epoch bumps invalidate Riverpod state mid-rebuild; feed provider also reset the force-refresh flag during its own create. Both abort the frame and leave the list loading.

**Fix:** Post-frame invalidate; clear the force-refresh flag only after the first `await` in the catalog provider.
