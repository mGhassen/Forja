# 328 — VidNest stale server backends open the wrong title

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/vidnest.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I328-T01 | Align movie/TV API paths with live `vidnest.fun` player (Zeta, Filxer, remapped Gama/Alfa/…) | ✅ |
| 2 | I328-T02 | Lamda = English / Delta = Hindi on shared `allmovies` streams | ✅ |
| 3 | I328-T03 | Feature + changelog docs (pack version bump) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I328-A01 | Sources → VidNest lists site servers (Lamda / Zeta / Filxer / Ophim / …) when upstream answers | ✅ |
| 2 | I328-A02 | Pin VidNest on a known TMDB title — stream matches that title (not a random MovieBox hit) | ⬜ |

---

## Summary

VidNest on Forja kept probing **old** `new.vidnest.fun` backends (e.g. Gama → `moviebox`, Alfa → `moviesapi`, Catflix → `movies5f`) and omitted **Zeta** / **Filxer**. The live site remapped those chips (Gama → `vidzee`, Filxer → `rogflix`, Zeta → `nextgencloudfabric`, …). Stale MovieBox-style hits often played a different title than the catalog row.

### Fix

- Default server table matches the current embed player order and paths
- Lamda / Delta still share `allmovies` but keep English vs Hindi rows
- Dropped obsolete `moviebox` / `moviesapi` / `movies5f` / `hollymoviehd` defaults that no longer back those chips

### Related

- [055](055-[fixed]-vidnest-moviebox-referer-429.md) — MovieBox Referer 429  
- [165](../165-[open]-vidnest-cdn-forced-referer.md) — forced embed Referer on CDNs  
- [082](../082-[open]-multi-server-collect-all.md) — collect every VidNest mirror  
- [stream providers](../../features/sources/stream-providers.md)
