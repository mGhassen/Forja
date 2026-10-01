# 332 — FlixCloud hop returns encrypted master (Sources empty)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/flixcloud.js` · ReAnime hop · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I332-T01 | Confirm live `dec-flixcloud` stream URL serves AES-wrapped master (not `#EXTM3U`) | ✅ |
| 2 | I332-T02 | Return `enc-dec.app/api/parse-flixcloud?url=&w_payload=` as playable row | ✅ |
| 3 | I332-T03 | Drop false Sources `flixcloud` HTTP chip (hop-only); keep `?v=` on ReAnime embeds | ✅ |
| 4 | I332-T04 | Providers pack bump + changelog + engine script assert | ✅ |
| 5 | I332-T05 | ReAnime: merge `/api/flix/{alId}/{ep}` embeds (do not skip when watch HTML has noise links) | ✅ |
| 6 | I332-T06 | FlixCloud: brace-parse page data + CF detect + chrome/plain fetch fallback | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I332-A01 | Live: token → m3u8 → stream decrypt → parse-flixcloud returns `#EXTM3U` | ✅ |
| 2 | I332-A02 | App: ReAnime → FlixCloud hop lists a playable row (manual) | ⬜ |

---

## Summary

FlixCloud decrypt via enc-dec yields a CDN `master.m3u8` whose **body is still AES-wrapped**. Probes expect `#EXTM3U` and drop the row → Sources shows nothing (or a dead URL). EncDec’s own sample feeds players **`/parse-flixcloud`** with `url` + `w_payload`, which decrypts the master and rewrites nested audio/video URIs.

Second miss: ReAnime only called `/api/flix/{anilist}/{ep}` when watch-page scrape found **zero** links. Non-FlixCloud `data-link` noise on the watch page skipped the API, so hops never saw real `flixcloud.cc/e/…` embeds.

### Fix

- Hop extract returns the parse-flixcloud URL (Chrome TLS fetch when available; brace-parse SSR data; CF challenge logged)
- ReAnime merges flix API `servers[].dataLink` with watch-page FlixCloud URLs only
- Remove the non-functional Sources **FlixCloud** HTTP chip (file-host hop only)

### Related

- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md) — EncDec / ReAnime + FlixCloud hop
- EncDec sample: `samples/flixcloud.py` (`parse-flixcloud`)
