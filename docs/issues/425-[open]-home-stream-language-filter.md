# 425 — Home details: stream language multiselect filters providers

**Status:** open  
**Priority:** P1  
**Severity:** Medium  
**Area:** Home · Sources · Providers · Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **12 / 12** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I425-T01 | SDK manifest `languages: [{ kind, code }]` + EnginePlugin parse | ✅ |
| 2 | I425-T02 | Annotate movie/tv providers; bump providers pack | ✅ |
| 3 | I425-T03 | Home `filters.play` multiselect + Settings `streamLanguages` (empty = all) | ✅ |
| 4 | I425-T04 | Details hero dropdown (dynamic union) + Settings chips | ✅ |
| 5 | I425-T05 | Pre-run gate Sources + Green Play from PackSettingsStore | ✅ |
| 6 | I425-T06 | Changelog | ✅ |
| 7 | I425-T07 | Exclusive SUB\|DUB selection; menu stays open on check; larger menu | ✅ |
| 8 | I425-T08 | Labels VO / VF / Arabic; annotate arabic providers `dub:ar` | ✅ |
| 9 | I425-T09 | Strict match (undeclared ≠ match); Sources/Green Play race language matches | ✅ |
| 10 | I425-T10 | Stamp `languages` into extract ctx | ✅ |
| 11 | I425-T11 | Changelog + feature doc for UX/filter fix | ✅ |
| 12 | I425-T12 | Language filter stays hub-scoped (Home ≠ arabic providers) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I425-A01 | Home details language multiselect lists langs declared by installed movie/tv plugins | ⬜ |
| 2 | I425-A02 | Empty selection runs all plugins; non-empty skips plugins whose `languages` do not intersect (undeclared skip) | ⬜ |
| 3 | I425-A03 | Green Play and Sources respect the same Settings-backed selection | ⬜ |

---

## Summary

Home needs a Sub/Dub-style language filter like Anime, but as a **multiselect within one kind** (`kind` + `code`: VOST / VOSTFR / VO / VF / …). Options come from the union of installed **hub-scoped** provider `languages` (Home = movie/tv only). Selection lives in hub Settings (`streamLanguages`); empty = run all. Green Play and Sources skip non-matching plugins before extract, still inside the hub category. SUB and DUB selections are exclusive.

**Undeclared plugins** do **not** run when a filter is set. Arabic-hub scrapers never appear on Home.

## Related

- Anime `filters.play` SUB/DUB (`hubs/anime`)
- [441](fixed/441-[fixed]-anime-dub-language-dropdown.md) — Anime dub-only language dropdown (same Settings field)
- Pack settings multiSelect (RFC-089)
- Green Play (RFC-118)
