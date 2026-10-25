# 490 — Android TV Forja Packs: ↓ on details chevron freezes

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** Android TV · Settings → Forja Packs · D-pad  
**Reported:** 2026-10-25 (device logs: endless `KeyRepeatEvent` Arrow Down, `focus=settings-pack-details`)

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On **Android TV**, Settings → Forja Packs: when focus is on a pack row’s **details** chevron (`settings-pack-details`), holding **↓** (or ↑) freezes / janks the UI. Logs show the same focus label on every KeyRepeat — focus never moves.

## Root cause (hypothesis until verified in code)

`_SettingsTvExpandableSideRow` details tap wires ←/→ only. Zone `settings` without `tvRowId` skips coordinator ↓. Spatial `focusInDirection` from the narrow right-side chevron often misses (same geometry class as [262](fixed/262-[fixed]-android-tv-forja-packs-last-pack-clipped.md)). Each KeyRepeat still runs HoldAccel multi-step spatial walks over a heavy packs tree → UI stall while focus stays stuck.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I490-T01 | Details chevron `onUpEdge` / `onDownEdge`: spatial walk from full-width header; claim edge so KeyRepeat cannot storm | 🔄 |
| 2 | I490-T02 | Widget test: ↓ from details moves focus off `settings-pack-details` | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I490-A01 | Android TV Settings → Forja Packs: ↓ / ↑ from details chevron moves focus; hold ↓ does not freeze | ⬜ |

## Links

- [262](fixed/262-[fixed]-android-tv-forja-packs-last-pack-clipped.md) · [127](fixed/127-[fixed]-android-tv-settings-detail-dpad.md) · [447](fixed/447-[fixed]-install-packs-dpad-cant-reach-install.md)
