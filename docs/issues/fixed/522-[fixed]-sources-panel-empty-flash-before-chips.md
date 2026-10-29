# 522 — Sources provider chips not instant on open

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Android TV · Sources panel · media details / player  
**Reported:** 2026-10-29 (released ATV — open Sources → no chips, empty copy, then populate)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-T01 | Treat chrome hydrate (packs/addons/indexers) as fetching — spinner instead of empty copy while chip lists pending | ✅ |
| 2 | I522-T02 | Forja pack-install loading counts as list fetching even with empty selection | ✅ |
| 3 | I522-T03 | Arm visible-kind fetch flags in the same frame hydrate clears / kind switches — no empty gap before ensure awaits | ✅ |
| 4 | I522-T04 | Cancel clears chrome hydrate; ensure* still starts when only armed (no in-flight ids yet) | ✅ |
| 5 | I522-T05 | Sync-seed chip lists on open from peekPacks / torrent catalog / Nuvio+Stremio mem (installed → instant chips) | ✅ |
| 6 | I522-T06 | Details warm fills pack/addon/torrent chip inventories before Sources open | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I522-A01 | ATV: open Sources on a title with packs already installed — provider chips visible on first paint (no empty wait) | ⬜ |
| 2 | I522-A02 | Desktop/phone: same — chips instant when inventories are warm | ⬜ |

---

## Symptom

On Android TV (released), opening Sources shows no provider chips and briefly paints empty copy, freezes a beat, then chips and streams appear — even though providers are already installed.

## Root cause

`_seedOptimisticChrome` only seeded kind tabs + stream cache. Chip inventories (`_enginePacks` / torrent catalog / Nuvio / Stremio) waited on `_bootstrap` prefs awaits. Packs were in `peekPacks` mem but unused on open. Spinner-only was the wrong fix; chips must sync-seed from warm mem.

## Links

- [177](../177-[open]-sources-selected-provider-lazy-fetch.md) — chip/fetch timing
- [178](../178-[open]-nuvio-empty-first-scraper-hides-streams.md) — premature empty after first scraper
- [337](337-[fixed]-sources-panel-jank-many-streams.md) — jank with many streams (separate)
