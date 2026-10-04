# 415 — Miruro Sources empty (catalog v1 API)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/miruro.js` · Anime Sources · Miruro

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I415-T01 | Replace dead `/api/secure/pipe` client with `/api/v1/anime` lookup + `/play` | ✅ |
| 2 | I415-T02 | Decode `application/octet-stream` catalog bodies (`miruro/catalog` XOR + gzip) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I415-A01 | Anime → One Piece E1 → Miruro lists playable Sub/Dub HLS rows | ⬜ |

---

## Summary

Miruro 1.15 dropped `/api/secure/pipe`. The site looks up titles with `GET /api/v1/anime?anilist_id_in=` and plays with `GET /api/v1/anime/{id}/episodes/{n}/play`. Catalog JSON is `application/octet-stream`: XOR with `miruro/catalog`, then gzip.

The old plugin encoded pipe payloads and returned no rows.

**Root fix:** v1 catalog + play. Engine fetch keeps octet-stream as raw `bodyB64` so XOR+gzip decode works. Providers pack **1.6.44**.

**Related:** [080](../080-[open]-miruro-cf-pipe-webview-unlock.md) is the old Anime-tab Dart/Rust pipe, not this Sources plugin.
