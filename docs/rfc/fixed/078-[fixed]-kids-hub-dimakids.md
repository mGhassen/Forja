# RFC-078: Kids hub (Dimakids) + provider

**Status:** fixed  
**Depends on:** RFC-070 (catalog hub protocol)  
**Area:** `plugins/hubs/kids/`, `plugins/providers/dimakids.js`, host nav asset map

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **6 / 6** acceptance |
| **Current slice** | Shipped — enable Kids pack in Forja Packs |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R78-C01 | ForjaHQ Kids hub pack (`dimakids-hub`, tab Kids) | ✅ |
| 2 | R78-C02 | Dimakids provider: page → foupix MP4 (`videoSrc`) | ✅ |
| 3 | R78-C03 | Host: nav Material fallback + skip probe for signed CDN | ✅ |

---

## Acceptance (hub + stream)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R78-A01 | Nav tab **Kids** (`tabId: kids`) from pack `nav`, default off | ✅ |
| 2 | R78-A02 | Feed/rails: series, movies, recent episodes from Dimakids HTML | ✅ |
| 3 | R78-A03 | Search via `search_results.php` JSON (series + movies) | ✅ |
| 4 | R78-A04 | Details lists episodes with `dimakids:` playable page urls | ✅ |
| 5 | R78-A05 | Provider extract returns foupix MP4 with matching UA/Referer | ✅ |
| 6 | R78-A06 | Films / Series menus + Arabic letter Categories from pack `filters` | ✅ |

---

## Summary

[Dimakids](https://www.dimakids.com/) is an Arabic kids cartoon/movie catalog (custom PHP site — not WordPress). Browse uses `cartoon.php` / `movies.php` / `{n}-tri.html` letter pages and home rails; search uses `search_results.php?q=…&ajax=1`. Episode and movie pages embed a Clappr `videoSrc` MP4 on `stream.foupix.com` (token locked to UA/IP).

Ship a dedicated **Kids** catalog hub and a **dimakids** provider that scrapes the play page for the real MP4. Reuse host `open.surface: arabic` (no new host surface).

### Goals

- One hub tab for Dimakids kids cartoons/movies (label **Kids**)
- Browse/search/details in the pack; play via `dimakids` provider
- Group seasons (الموسم / الجزء) like كرتون
- Skip CDN probe (signed URLs false-fail on HEAD)

### Out of scope

- TMDB enrich companion
- Books / wallpapers / live TV sections on Dimakids
- Embedding / WebView playback
