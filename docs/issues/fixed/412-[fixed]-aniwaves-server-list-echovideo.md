# 412 — AniWaves Sources empty (server list + EchoVideo)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/aniwaves.js` · Anime Sources · AniWaves

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I412-T01 | Pass episode `data-ids` as `servers={id}&eps={n}` (do not URL-encode `&`) | ✅ |
| 2 | I412-T02 | Resolve Vidplay via `play.echovideo.ru/embed-N/getSources` to an HLS URL | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I412-A01 | Anime → Naruto E1 → AniWaves lists a playable Sub/Dub stream | ⬜ |

---

## Summary

AniWaves `/filter?keyword=` and `/ajax/episode/list/{id}` still work. Episode rows use `data-ids="76396&amp;eps=1"`. The site loads servers with `GET /ajax/server/list?servers=76396&eps=1`. Extract encoded the whole ids string, so the list returned empty and Sources showed nothing.

Vidplay embeds are `https://play.echovideo.ru/embed-1/{id}`. There is no hop for that host. `GET /embed-1/getSources?id={id}` with that page as Referer returns `{ sources: "https://….m3u8" }`. Playback uses Referer/Origin on the EchoVideo origin (CDN answers `image/jpeg` but the body is HLS).

**Root fix:** unencoded server-list query + EchoVideo `getSources`. Providers pack **1.6.39**.
