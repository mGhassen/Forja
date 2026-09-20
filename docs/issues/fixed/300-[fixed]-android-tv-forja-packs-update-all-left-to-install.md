# 300 — Android TV Forja Packs: ← from Update all never reaches Install

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** settings / Forja Packs / Android TV / D-pad

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** tasks · **0/2** acceptance (manual QA) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I300-T01 | Wire **Update all** `onLeftEdge` → Install focus node | ✅ |
| 2 | I300-T02 | Wire Install `onRightEdge` → **Update all** when updates exist | ✅ |
| 3 | I300-T03 | Changelog + feature guide | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I300-A01 | ATV Settings → Forja Packs with updates: focus **Update all**, ← lands on **Install** | ⬜ |
| 2 | I300-A02 | Same screen: focus **Install**, → lands on **Update all** | ⬜ |

---

## Summary

On Android TV Settings → Forja Packs, D-pad ← from **Update all** did not move to **Install**.

**Root cause:** Shell DirectionalFocus no-ops ←/→. Reload / Install already had explicit `onLeftEdge` / `onRightEdge`, but **Update all** (built inside `SettingsEnginePackUpdatesBar`) had none — spatial fallback never hops left.

**Root fix:** Owned focus node on **Update all** + `onLeftEdge` → Install; Install `onRightEdge` → **Update all** when updates are showing.

## Related

- `apps/forja/lib/features/settings/packs/engine_pack_update.dart`
- `apps/forja/lib/features/settings/packs/packs_section.dart`
- [features/settings/forja-packs.md](../../features/settings/forja-packs.md)
