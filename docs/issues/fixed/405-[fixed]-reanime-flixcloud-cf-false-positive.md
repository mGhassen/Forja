# 405 — ReAnime Sources empty (FlixCloud Cloudflare false positive)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/flixcloud.js` · `reanime.js` · Anime Sources

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I405-T01 | Parse FlixCloud SSR `type:"data"` before treating the page as a Cloudflare challenge | ✅ |
| 2 | I405-T02 | ReAnime search uses `/api/v1/search` (AniList id + real slug); ignore nav slugs like `search` | ✅ |
| 3 | I405-T03 | Providers pack bump + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I405-A01 | Anime → Black Clover E1 → ReAnime lists a playable FlixCloud stream | ⬜ |

---

## Summary

ReAnime found two FlixCloud embeds (`/api/flix/{anilist}/{ep}`), then the hop returned empty. Embed HTML includes Cloudflare’s `cdn-cgi/challenge-platform/scripts/jsd` beacon **and** the SvelteKit player payload (`type:"data",data:{…}`). The hop matched `challenge-platform` first and never parsed the data. EncDec `dec-flixcloud?type=token` still accepts that blob.

Search also scraped the SPA (`slug=search`) because `/api/search` is HTML; live search is `/api/v1/search`. Flix API still ran from the host AniList id, so the empty Sources row was the hop, not a miss.

**Root fix:** parse SSR data first; only flag Cloudflare when the payload is missing. Search `/api/v1/search`. Providers pack **1.6.29**.

### Related

- [332](332-[fixed]-flixcloud-encrypted-master-parse.md) — EncDec parse-flixcloud hop
