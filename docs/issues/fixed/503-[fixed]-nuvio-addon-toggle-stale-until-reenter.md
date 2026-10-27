# 503 — Nuvio addon enable toggle stale until leave/reenter Settings

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Settings · Nuvio addons  
**Reported:** 2026-10-27 (manual — switch stayed off until navigating away)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · 2/2 fix · 0/1 acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Settings → Nuvio → installed addon row (e.g. All-in-One-Nuvio): flip the enable Switch → track stays grey. Leave the panel and come back → Switch shows on. Persist was fine; UI did not refresh in place.

## Root cause

`NuvioAddonsNotifier` listened to `NuvioService.changeNotifier` with `ref.invalidateSelf()` and painted `AsyncLoading` on reload. Packs already abandoned that pattern (`EnginePacksNotifier`) because invalidate/loading remounts ExpansionTiles and leaves header chrome on the pre-toggle value. Nuvio still used the old path (`settings_panel_providers.dart`).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I503-T01 | Mirror packs: changeNotifier → microtask `reload()` (no invalidateSelf) | ✅ |
| 2 | I503-T02 | `reload()` swaps list without AsyncLoading when prior value exists | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I503-A01 | Toggle Nuvio addon Switch — track flips immediately without leaving Settings | ⬜ |

## Links

- Packs precedent: `EnginePacksNotifier` reload (same file)
