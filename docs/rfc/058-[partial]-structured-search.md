# RFC-058: Structured Search (person / genre / year)

**Status:** partial  
**Depends on:** —  
**Area:** `packages/rust/lib/src/catalog/`, `apps/forja/lib/features/search/`  
**Version:** v1.4 Atarin

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **8 / 10** acceptance · **0 / 1** device smoke |
| **Current slice** | Score / type / filter lens shipped — device smoke still open |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R58-C01 | `parseSearchQuery` — year / range / genre aliases + remainder | ✅ |
| 2 | R58-C02 | `TmdbApi.searchStructured` + Search tab uses it (addons still raw) | ✅ |
| 3 | R58-C03 | Search filter lens UI (type segment / score arc / year timeline) + query compose | ✅ |

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

## Acceptance (score / type / filter lens)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R58-A07 | Query tokens `>8` / `>=8` / `<9` / `8-9` and `films`/`series` parse into score + mediaType | ✅ |
| 2 | R58-A08 | TMDB discover + multi-search honor min/max score and movie/tv type | ✅ |
| 3 | R58-A09 | Tune icon opens filter lens; active filters dock as clearable ghost tokens | ✅ |
| 4 | R58-A10 | Addon search uses remainder only (skips when filters-only) | ✅ |

---

## Summary

Upgrade Search’s TMDB path from raw `search/multi` to a structured merge: parse year (or range), genre aliases, score bounds, and media type, resolve leftover text as a person when confident, run discover with those filters, and merge with title multi-search (year/score/type-filtered when asked). A filter lens UI composes the same tokens. Stremio addon search receives the remainder text only (skipped for filters-only queries).

## Goals

1. Queries like `nolan 2022-2025` and `horror 2025` return useful catalogs without a separate Discover UI.
2. Keep the Search UI sections unchanged (TMDB Movies / Shows + addons).
3. Stay thin — local parse + existing discover APIs; no NLP service.

## Contracts

- Person rows are never shown; only movie/tv cards.
- Year/range on title multi-hits is a hard filter when present.
- Genre aliases are exact token/phrase matches (see `search_query_parser.dart`).
- TV has no Horror genre — horror queries discover movies only.
- Score filters use TMDB `vote_average` (discover gte/lte + post-filter).
- Media type tokens (`films` / `series`) restrict movie vs TV.
- Addon catalogs: remainder text only; skipped when the query is filters-only.
