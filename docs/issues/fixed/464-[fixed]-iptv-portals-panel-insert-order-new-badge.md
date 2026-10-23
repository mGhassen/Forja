# 464 — IPTV Portals panel lost insert-date order + NEW badge

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** IPTV · Portals panel · inventory  
**Reported:** 2026-10-23 (regression vs 1.4)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

Opening IPTV **Portals**, the list reorder jumps (favorites / cloud pull). Newly added portals land at the bottom with no **NEW** badge — 1.4 put them on top with a badge until hover/select.

## Root cause (verified)

- Pack `iptvUpsertPortalRow` **appends**; no `addedAt`
- Host `_inventoryFromRows` only favorites-first; never sets `isNew`
- Cloud pull rebuilds vault from `user_iptv_portals.created_at` **ascending**
- Legacy `IptvController` `_portalRecencyKeys` / `_newPortalKeys` removed in 2.x; foundation still paints `NEW` when `isNew`

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I464-T01 | Stamp `addedAt` on new vault/store portal rows (pack upsert + cloud pull + CSV) | ✅ |
| 2 | I464-T02 | Panel sort: favorites first, then `addedAt` desc (newest insert on top) | ✅ |
| 3 | I464-T03 | Session NEW keys + `isNew` paint; clear on desktop hover / select (not TV skim) | ✅ |
| 4 | I464-T04 | Changelog + feature note; host unit test for sort / isNew | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I464-A01 | Add / import / deal / cloud-assign → portal on top (after favorites) with NEW | ⬜ |
| 2 | I464-A02 | Hover (desktop) or select clears NEW; TV ↑/↓ skim does not; order stays insert-date | ⬜ |

## Links

- Related: [229](fixed/229-[fixed]-iptv-add-wiped-by-panel-cloud-pull.md) · [349](fixed/349-[fixed]-iptv-portal-favorite-star-lag.md)
