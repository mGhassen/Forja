# RFC-079 — Sources ID middleware

**Status:** open  
**Depends on:** [RFC-054](054-[partial]-torrent-search-providers.md), [RFC-070](070-[partial]-catalog-hub-protocol.md)  
**Area:** Sources / catalog kit

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **8 / 8** acceptance |
| **Current slice** | Host middleware + Sources rewire shipped — manual QA remaining |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R79-C01 | `SourcesRequestContext` bag merge + engine / torrent / nuvio slices | ✅ |
| 2 | R79-C02 | Stremio projector (`idPrefixes` → bag scheme → stream id) | ✅ |
| 3 | R79-C03 | Sources panel + hub play pass `CatalogMetaItem` through middleware | ✅ |
| 4 | R79-C04 | Torrent JS ctx accepts opaque `ids` map | ✅ |

---

## Acceptance (middleware slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R79-A01 | Bag merges `meta.ids` + extract.ctx + Movie imdb fallback (no hub pack switches) | ✅ |
| 2 | R79-A02 | Engine `tmdbId` never uses hub open.id / synthetic when `ids.tmdb` absent | ✅ |
| 3 | R79-A03 | Torrent search uses bag imdb + title query; JS ctx carries opaque `ids` | ✅ |
| 4 | R79-A04 | Nuvio skipped when numeric `ids.tmdb` missing (no AniList/KissKh as tmdb) | ✅ |
| 5 | R79-A05 | Stremio picks stream id per addon `idPrefixes`; skips addon when no bag match | ✅ |
| 6 | R79-A06 | Custom Stremio open extras still bypass bag/`idPrefixes` | ✅ |
| 7 | R79-A07 | Synthetic host tests cover bag / nuvio skip / stremio prefix pick | ✅ |
| 8 | R79-A08 | Feature + changelog note Sources id mapping | ✅ |

---

## Summary

Catalog packs emit opaque id bags; Sources kinds need different inputs. One host middleware merges `meta.ids` + `CatalogOpen.extract.ctx` + Movie fallbacks and projects fixed slices for Forja providers, torrents, and Nuvio. Stremio resolution is a separate projector that reads each addon's `idPrefixes`.

## Goals

- Input-driven mapping (scheme names), not hub/pack switches
- Never pass wrong hub ids as TMDB to Nuvio or engine
- Stremio addons that need non-IMDb prefixes can run when the bag has that scheme
- Packs remain responsible for enriching `ids` (IMDb via enrich already in RFC-054)

## Related

- [RFC-054](054-[partial]-torrent-search-providers.md) — torrent path consumes this middleware
- [Torrent scrapers](../features/scrapers/torrent.md)
