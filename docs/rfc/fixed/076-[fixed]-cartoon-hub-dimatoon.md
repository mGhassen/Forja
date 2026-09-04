# RFC-076: كرتون hub (DimaToon) + provider fix

**Status:** fixed  
**Depends on:** RFC-070 (catalog hub protocol)  
**Area:** `plugins/hubs/cartoon/`, `plugins/providers/dimatoon.js`, host nav asset map

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **6 / 6** acceptance |
| **Current slice** | Shipped — enable Cartoon pack in Forja Packs |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R76-C01 | ForjaHQ Cartoon hub pack (`dimatoon-hub`, tab كرتون) | ✅ |
| 2 | R76-C02 | DimaToon provider: skip Plyr `blank.mp4`, real CDN MP4 | ✅ |
| 3 | R76-C03 | Arabic hub: drop DimaToon from search (details/stream kept for old ids) | ✅ |

---

## Acceptance (hub + stream)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R76-A01 | Nav tab **كرتون** (`tabId: cartoon`) from pack `nav`, default off | ✅ |
| 2 | R76-A02 | Feed/rails: latest series, popular, recent episodes via WP REST | ✅ |
| 3 | R76-A03 | Search via DimaToon ajax + WP taxonomy search | ✅ |
| 4 | R76-A04 | Details lists episodes with `dimatoon:` playable ids | ✅ |
| 5 | R76-A05 | Provider extract returns `site.word.tn` (or real) MP4, never blank.mp4 | ✅ |
| 6 | R76-A06 | Arabic search no longer merges DimaToon (كرتون owns browse) | ✅ |

---

## Summary

[Dima Toon](https://www.dima-toon.com/) is an Arabic dubbed cartoon/anime catalog (WordPress: taxonomy `cartoon`, CPT `cartoon-episode`). It was bolted onto the Arabic hub for search only and a thin provider that often returned Plyr’s placeholder `blank.mp4` when Cheerio was unavailable.

Ship a dedicated **كرتون** catalog hub backed by WP REST + site ajax, and fix the **dimatoon** provider to pick the real `<source>` / CDN MP4.

### Goals

- One hub tab for Arabic cartoons (label **كرتون**)
- Browse/search/details entirely in the pack; play via existing `dimatoon` provider
- Reuse host `open.surface: arabic` + `resolveType: arabic` (no new host surface)
- Keep Arabic hub details/stream paths for legacy `dimatoon:` list/history ids

### Out of scope

- TMDB enrich companion
- Host feature folder / `anime_arabic` revive
- Embedding / WebView playback
