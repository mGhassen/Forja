# 522 — Sources panel empty flash before provider chips

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · Sources panel · media details / player  
**Reported:** 2026-10-29 (released ATV — open Sources → no chips, empty copy, then populate)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-T01 | Treat chrome hydrate (packs/addons/indexers) as fetching — spinner instead of empty copy while chip lists pending | ✅ |
| 2 | I522-T02 | Forja pack-install loading counts as list fetching even with empty selection | ✅ |
| 3 | I522-T03 | Arm visible-kind fetch flags in the same frame hydrate clears / kind switches — no empty gap before ensure awaits | ✅ |
| 4 | I522-T04 | Cancel clears chrome hydrate; ensure* still starts when only armed (no in-flight ids yet) | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-A01 | ATV: open Sources on a title — spinner until chips appear; no “Select at least one provider” / “No matching sources” flash | ⬜ |
| 2 | I522-A02 | Desktop/phone: same open path — no empty-copy flash before chips | ⬜ |

---

## Symptom

On Android TV (released), opening Sources shows no provider chips and briefly paints empty copy (“no streams” / select-provider / no matches), freezes a beat, then chips and streams appear.

## Root cause

`PlayerSourcesPanel` seeded kind/cache rows but left chip lists empty until `_bootstrap` awaited prefs + packs/addons. `_isFetching` was false in that window (and Forja pack-install required a non-empty selection), so `totalCount == 0` painted empty copy instead of the loading spinner. Chip row is hidden when `providerOptions.isEmpty`.

## Links

- [177](../177-[open]-sources-selected-provider-lazy-fetch.md) — chip/fetch timing
- [178](../178-[open]-nuvio-empty-first-scraper-hides-streams.md) — premature empty after first scraper
- [337](337-[fixed]-sources-panel-jank-many-streams.md) — jank with many streams (separate)
