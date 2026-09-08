# 243 — Android TV Live Sports first focus lands on Catalog

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Live Sports · Android TV · `ShellTvFocusCoordinator` · `KitListWidget`  
**Reported:** 2026-09-08  

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I243-T01 | `enterTabFromNav`: treat top-bar chrome focus as miss; drop polluted Catalog memory before fallback restore | ✅ |
| 2 | I243-T02 | `KitTopBarActions`: register Catalog/Schedule row with negative `sortOrder` (chrome, not first content) | ✅ |
| 3 | I243-T03 | `KitListWidget`: `defaultFocus` + enter/restore land on category → status → list (retry frames) | ✅ |
| 4 | I243-T04 | `KitTopBarActions`: drop empty ←/→ edge no-ops so Catalog→Schedule→Refresh→Portals walks via row meta | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I243-A01 | Manual Android TV: OK on Live Sports / Cards nav → focus on sport **All**; ↑ Catalog; → walks Catalog → Schedule → Refresh → Portals | ⬜ |

---

## Summary

**Symptom:** On Android TV, opening Live Sports put D-pad on the top **Catalog** chip first.

**Root cause:** Tab paint autofocuses the first focusable (Catalog). `enterTabFromNav` treated any page focus as success, so retries stopped while still on chrome. Catalog autofocus also wrote `topBar` memory that the enter fallback restored.

**Fix:** Enter success requires content focus (not `ShellTvZone.topBar`); strip topBar memory on enter fallback; kit top bar registers as chrome (`sortOrder < 0`); list enter/restore targets category bar then list. Empty `onLeftEdge` / `onRightEdge` no-ops on Catalog→… chips were removed so row meta walks ←/→ across the top bar.
