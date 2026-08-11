# RFC-058: Structured Search (person / genre / year)

**Status:** partial  
**Depends on:** —  
**Area:** `packages/rust/lib/src/catalog/`, `apps/forja/lib/features/search/`  
**Version:** v1.4 Atarin

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** components · **5 / 6** acceptance · **0 / 1** device smoke |
| **Current slice** | Parser + TMDB structured search wired — device smoke open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R58-C01 | `parseSearchQuery` — year / range / genre aliases + remainder | ✅ |
| 2 | R58-C02 | `TmdbApi.searchStructured` + Search tab uses it (addons still raw) | ✅ |

---

## Acceptance (1.4.0)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R58-A01 | `nolan` / `christopher nolan` returns person filmography via discover | ✅ |
| 2 | R58-A02 | `nolan 2025` and `nolan 2022-2025` filter person credits by year/range | ✅ |
| 3 | R58-A03 | `horror 2025` / `sci-fi 2024` discover by genre + year | ✅ |
| 4 | R58-A04 | Plain title queries still use multi-search (no false genre/person) | ✅ |
| 5 | R58-A05 | Feature doc + changelog + parser unit tests | ✅ |
| 6 | R58-A06 | Desktop / phone / ATV smoke on structured queries | ⬜ |

---

## Summary

Upgrade Search’s TMDB path from raw `search/multi` to a structured merge: parse year (or range) and genre aliases, resolve leftover text as a person when confident, run discover with those filters, and merge with title multi-search (year-filtered when a year was asked). Stremio addon search still receives the raw query string.

## Goals

1. Queries like `nolan 2022-2025` and `horror 2025` return useful catalogs without a separate Discover UI.
2. Keep the Search UI sections unchanged (TMDB Movies / Shows + addons).
3. Stay thin — local parse + existing discover APIs; no NLP service.

## Contracts

- Person rows are never shown; only movie/tv cards.
- Year/range on title multi-hits is a hard filter when present.
- Genre aliases are exact token/phrase matches (see `search_query_parser.dart`).
- TV has no Horror genre — horror queries discover movies only.
- Addon catalogs: unchanged raw `search` param.
