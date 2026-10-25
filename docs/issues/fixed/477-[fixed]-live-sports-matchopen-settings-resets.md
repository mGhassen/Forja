# 477 — Live Sports Open matches in resets to Detail page

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Live Sports · pack settings · `matchOpen`  
**Reported:** 2026-10-25 (Android TV Settings → Forja Packs → Live Sports Setup)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

User sets **Open matches in → Side panel**. The select snaps back to **Detail page** (prefs / UI do not keep `panel`).

## Root cause

1. Packs expand rebuilds allocate a new `plugins` list every frame. `PackAddonSettingsSection.didUpdateWidget` compared list **identity**, so every rebuild started `_reload()`.
2. Closing the TV select dialog rebuilds Settings while `_setString` is still writing. A stale `_reload` that read prefs **before** the write then `setState`’d the old `details` value over the user’s pick.
3. `reloadHub: false` writes skipped `onNonSecretUserWrite`, so signed-in soft pulls could also re-apply a stale cloud `matchOpen`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I477-T01 | Compare plugin ids (not list identity) before `_reload` | ✅ |
| 2 | I477-T02 | Reload gen + paint-before-write so stale reloads cannot stomp selects | ✅ |
| 3 | I477-T03 | `reloadHub: false` still schedules pack-settings sync push | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I477-A01 | Android TV: Open matches in → Side panel stays Side panel after dialog close / leaving Setup | ⬜ |
| 2 | I477-A02 | Match OK opens Providers beside the schedule when Side panel is selected | ⬜ |

## Links

- [313](313-[fixed]-android-tv-live-sports-side-panel-opens-details.md) — panel vs details open path
- [314](314-[fixed]-live-sports-settings-wipes-feed-cache.md) — `reloadHub: false` for matchOpen
