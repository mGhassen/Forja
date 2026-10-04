# 414 — Luna Sources empty (stale Next-Action)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/luna.js` · Anime Sources · Luna

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I414-T01 | Stop POSTing luna-stream.me Next-Action (hash rotated; play action returns null) | ✅ |
| 2 | I414-T02 | Extract via api.luna-stream.me megaplay/anidb/aniwaves/animegg sources | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I414-A01 | Anime → Death Note E1 → Luna lists a playable stream | ⬜ |

---

## Summary

Luna extract POSTed a hardcoded Next.js server action on luna-stream.me. That hash no longer matches the build, so the site returned HTML instead of RSC. The current play action also returns `null` on the website itself (degraded). The public extractor at `api.luna-stream.me` still serves HLS/MP4 via `/anime/megaplay/sources`, `/anime/anidb/sources`, AniWaves search+sources, and AnimeGG search+episodes+sources.

**Root fix:** call those API routes and play the returned `proxyUrl`. Providers pack **1.6.43**.
