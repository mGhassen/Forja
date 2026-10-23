# 473 — My List Open with… too small; click does not persist / update card

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** Lists · Open with · desktop  
**Reported:** 2026-10-23 (desktop screenshot)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

1. **Open with…** on desktop is a phone-narrow card (~480×560) — hard to scan hubs + results.
2. Clicking a match row does nothing; only the tiny checkbox fires.
3. After a successful check, the My List poster keeps the old title/poster, and the dialog row stays unchecked if save never ran from a row click.

## Root cause

1. Desktop `SettingsTokens.bindSheet*` was a fixed 480×560 (TV got fractions in 469; desktop did not).
2. `_HitsBody` returned undecorated rows for `pickFilm` without `InkWell` — row tap was a no-op.
3. `persistBinding` / `stampListOpenBinding` wrote open keys only — not title/poster — and Open with never called `invalidateListHubFeeds`, so the grid kept a stale feed.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I473-T01 | Desktop bind sheet uses screen fractions (≥640×640) | ✅ |
| 2 | I473-T02 | pickFilm row / film-only row tap saves + checks; header preview updates | ✅ |
| 3 | I473-T03 | Stamp title/poster onto row + paint; invalidate My List feed after save | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I473-A01 | Desktop Open with… reads as a large picker (not a phone card) | ⬜ |
| 2 | I473-A02 | Click a match → checkbox on, card poster/title update, next open uses that hub | ⬜ |

## Links

- [400](../400-[open]-my-list-open-with-hub-checkbox.md) · [469](469-[fixed]-android-tv-open-with-sheet-size-dpad.md) · [RFC-108](../../rfc/fixed/108-[fixed]-my-list-open-hub-binding.md)
