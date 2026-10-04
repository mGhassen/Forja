# 413 — AniHQ Sources empty (VOE iframe + search)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/anihq.js` · `forja-packs/providers/hops/voe.js` · Anime Sources · AniHQ

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I413-T01 | Read VOE from episode `iframe src` / `data-embed-id` (no longer `data-video`) | ✅ |
| 2 | I413-T02 | Fall back to Kiranime `instant_search` (`s_keyword` AJAX), not `/search?keyword=` | ✅ |
| 3 | I413-T03 | Decode VOE `application/json` scripts that wrap the payload in a JSON array | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I413-A01 | Anime → One Piece E1 → AniHQ lists a playable Sub stream | ⬜ |

---

## Summary

Watch pages still live at `/watch/{slug}-episode-{n}-english-subbed/`. The player is an iframe (`https://voe.sx/e/…`) plus base64 `data-embed-id`. Extract only looked for `data-video` / `href`, so every title returned nothing.

HTML search at `/search?keyword=` is the empty Advanced Search shell. Live search is `GET /wp-admin/admin-ajax.php?action=instant_search&query=&nonce=` and returns `/anime-show/` hits.

VOE then redirects to a CDN host. The embed page puts the encoded player JSON in `<script type="application/json">["…"]</script>`. The hop treated that as a quoted string and never decoded `source`.

**Root fix:** iframe / `data-embed-id` + instant search + JSON-array VOE decode. Providers pack **1.6.42**.
