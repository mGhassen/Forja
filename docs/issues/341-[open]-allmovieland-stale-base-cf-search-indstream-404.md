# 341 — AllMovieLand empty Sources (stale base + CF search + IndStream 404)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/allmovieland.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 4** fix · **1 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I341-T01 | Point SPECS `base` at live `allmovieland.art` (`.one` 301s) | ✅ |
| 2 | I341-T02 | Search with `?do=search&subaction=search&story=` (story-first query hits CF managed challenge) | ✅ |
| 3 | I341-T03 | Resolve IndStream host from `player.js` + IMDB `/play/{tt…}` first; title search fallback with year from `/year/` | ✅ |
| 4 | I341-T04 | IndStream `/play/{id}` returns embed + playlist again (upstream CDN) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I341-A01 | curl: `allmovieland.art/?do=search&subaction=search&story=Inception` returns `article.short-mid` (not CF challenge) | ✅ |
| 2 | I341-A02 | curl: live `player.js` host `/play/tt1375666` returns embed with `p3` / `file`+`key` (not 404) | ⬜ |
| 3 | I341-A03 | App: Sources → AllMovieLand lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

Catalog moved: `allmovieland.one` → **`https://allmovieland.art`**. The old search query put `story=` before `do=search`, which Cloudflare challenges (403 “Just a moment…”). Reordered query + live base restore catalog search.

Streams still empty because the IndStream player CDN is down site-wide. Detail pages still embed stale `laika422mon.com`; `allmovieland.link/player.js` points at `slast430did.com`; `allmovieland.art/player.js` points at `protection-episode-i-222.site`. All return **404** for `/play/{imdb}` — including the site’s own browser iframe. Upstream extractors (CSX / MediaVanced) use the same path and are broken the same way.

**Forja host path (ready):** IMDB-first `/play/{tt…}` against hosts from `player.js`, then title search fallback. **Not fixed for users** until IndStream serves embeds again.

### Related

- [RFC-060](../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- [stream providers](../features/sources/stream-providers.md)
