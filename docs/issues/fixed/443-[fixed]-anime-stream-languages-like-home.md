# 443 — Anime stream languages match Home (drop duplicate SUB/DUB)

**Status:** fixed  
**Priority:** P1  
**Severity:** Medium  
**Area:** Anime · Sources · Providers · Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I443-T01 | Anime `filters.play`: remove grouped SUB/DUB; language multiselect both kinds (`types: [anime]`, no `kinds`) | ✅ |
| 2 | I443-T02 | Settings label → Stream languages; derive extract `category` from selected language keys | ✅ |
| 3 | I443-T03 | Green Play + Sources use inferred audio category when hub has no grouped filter | ✅ |
| 4 | I443-T04 | Changelog + anime feature doc | ✅ |
| 5 | I443-T05 | Language options = full hub-type union (not enabled-only); bust filters cache on details | ✅ |
| 6 | I443-T06 | Debug: overlay `languages` from `FORJA_PACKS_ROOT` providers manifest onto lean packs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I443-A01 | Anime details shows one SUB\|DUB language pill (like Home), not a separate SUB/DUB toggle + dub-only chip | ⬜ |
| 2 | I443-A02 | SUB menu lists VOST / VOSTFR / …; DUB menu lists VO / VF / Arabic / … from anime providers | ⬜ |

---

## Summary

[441](441-[fixed]-anime-dub-language-dropdown.md) kept the old SUB/DUB toggle and added a **dub-only** language chip — two DUB controls, no SUB dropdown. Anime now matches Home: one language multiselect, both kinds, Settings-backed `streamLanguages`. Selected keys of one kind stamp extract `category` so providers scrape that lane.

## Related

- [441](441-[fixed]-anime-dub-language-dropdown.md) — prior dub-only + toggle design
- [425](../425-[open]-home-stream-language-filter.md) — Home stream language filter
