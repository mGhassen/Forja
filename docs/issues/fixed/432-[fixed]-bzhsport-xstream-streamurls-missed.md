# 432 — BZH-Sport misses xstream / JW channel links

**Priority:** P1  
**Severity:** Medium  
**Status:** fixed  
**Area:** `forja-packs/livesports/bzhsport.js` — Live Sports resolve  
**Reported:** 2026-10-14  
**Fixed:** 2026-10-14  

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** fix · **0 / 2** acceptance (manual) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I432-T01 | Parse JW `streamUrls` on nested player pages (xstream.st) | ✅ |
| 2 | I432-T02 | Skip ad / empty-holdfold iframes when hopping | ✅ |
| 3 | I432-T03 | Pack `forjahq-livesports` 2.0.29 + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I432-A01 | Live match with beIN max / C+Live on BZH → Providers shows that named row (not only Link) | ⬜ |
| 2 | I432-A02 | Existing holdfold /player/3/* links still unlock | ⬜ |

---

## Summary

BZH event pages list several embeds. Named channels on `zonalive /player/4/*` nest into `xstream.st` with a JWPlayer `streamUrls` m3u8 list. Unlock only understood holdfold `_econfig`, then followed the first iframe (often a 1×1 ad) and dropped the channel.

## Root cause

`unlockEmbed` stopped at `_econfig` or a single iframe hop. xstream pages have no `_econfig`; their first iframe is an ad; the playable URLs sit in `const streamUrls=[…]`.

## Fix approach

Before hopping iframes, parse and live-probe `streamUrls`. When hopping, skip empty `holdfold.net/embed/` stubs and known ad frames. Holdfold `_econfig` path unchanged.

**Non-goals:** dlive.sx (geo legal wall), jack/mpanrc Nuxt pages (no native stream in HTML).
