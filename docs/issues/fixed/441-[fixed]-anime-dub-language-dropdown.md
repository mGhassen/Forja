# 441 — Anime details: dub language dropdown (Home-style)

**Status:** fixed  
**Priority:** P2  
**Severity:** Medium  
**Area:** Anime · Sources · Providers · Settings

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I441-T01 | Anime `filters.play` keep SUB/DUB + add `pluginLanguages` multiselect with `types: [anime]`, `kinds: [dub]` | ✅ |
| 2 | I441-T02 | Host: parse play/settings `types`/`kinds`; union filter; details + Settings load pack-scoped options | ✅ |
| 3 | I441-T03 | Annotate anime providers with `languages` (EN/FR/AR dub lanes) | ✅ |
| 4 | I441-T04 | Changelog + anime feature doc | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I441-A01 | Anime details shows DUB language dropdown (no SUB languages); SUB/DUB toggle still present | ⬜ |
| 2 | I441-A02 | Empty selection runs all anime providers; non-empty skips non-matching (hub-scoped to anime) | ⬜ |

---

## Summary

Anime keeps the grouped SUB/DUB extract lane toggle and adds Home’s language multiselect, restricted to **dub** languages from **anime**-typed providers. Selection is Settings-backed (`streamLanguages`); empty = all.

## Related

- [425](../425-[open]-home-stream-language-filter.md) — Home stream language filter
- [443](443-[fixed]-anime-stream-languages-like-home.md) — superseded UX: drop toggle, both kinds like Home
- Anime hub pack `hubs/anime`
