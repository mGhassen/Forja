# 409 — KickAssAnime finds a stream that will not play

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/kickassanime.js` · Anime Sources · KickAssAnime

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I409-T01 | Read CatStream player HTML and use the `props` master playlist (`bl.krussdomi.com`) | ✅ |
| 2 | I409-T02 | Send playback `Referer` + `Origin` `https://krussdomi.com` (segments 403 without Origin) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I409-A01 | Anime → Black Clover S1E1 → KickAssAnime CatStream opens and plays | ⬜ |

---

## Summary

Extract listed KickAssAnime · CatStream, then the player failed on `https://hls.krussdomi.com/manifest/{id}/master.m3u8` (HTTP 502). CatStream’s Astro player embeds the live manifest in page `props` as `//bl.krussdomi.com/playlist/{id}/master.m3u8`. Leaf segments are `.jpg` MPEG-TS on sibling CDNs; they return 403 unless both `Referer` and `Origin` are `https://krussdomi.com`.

**Root fix:** fetch the cat-player page, parse the playlist URL, play with those headers. Providers pack **1.6.34**.
