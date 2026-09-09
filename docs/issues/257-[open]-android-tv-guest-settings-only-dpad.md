# 257 — Android TV guest / Settings-only D-pad stuck on Settings rail

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** shell / Settings hub / Android TV D-pad

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I257-T01 | Skip cold-start nav focus when visible rail is Settings-only | ✅ |
| 2 | I257-T02 | Empty get-started registers `TvHeroActions` for `settings`; Settings hub discards empty-shell memory on mount | ✅ |
| 3 | I257-T03 | `restoreTabFocusAfterNav` falls through when row memory’s handle is gone; `focusActiveNavTab` no-ops for single-tab rail; page Back arms exit | ✅ |
| 4 | I257-T04 | Widget tests: dead empty-shell restore, Settings-only Left no-op, Settings-only Back arms exit | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I257-A01 | Widget tests in `shell_tv_coordinator_test.dart` pass | ✅ |
| 2 | I257-A02 | Android TV guest (no feature tabs): D-pad lands on get-started / Settings hub; → enters categories/detail; Back does not park forever on the Settings rail icon | ⬜ |

---

## Summary

Fresh guest install paints a Settings-only nav rail. Cold-start focused the Settings icon; Back from Settings also parked there. **→** tried to restore disposed `empty-shell-cards` row memory and never fell back to hub category focus — D-pad looked dead.

**Root fix:** body owns first focus when Settings-only; empty gate + Settings hub both register enter/restore; dead row memory falls through; single-tab Back arms exit instead of focusing the lone icon.

## Related

- [navigation](../features/getting-started/navigation.md)
- [253](253-[open]-starred-home-opens-on-settings.md) — starred Home cold start
- `apps/forja/lib/shared/foundation/tv/shell_tv_coordinator.dart`
- `apps/forja/lib/shell/frame/shell_empty_features_screen.dart`
- `apps/forja/lib/shell/nav/shell_nav_rail.dart`
