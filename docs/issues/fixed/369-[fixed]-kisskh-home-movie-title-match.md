# 369 — KissKh Home movies miss / wrong title (no tmdbID)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/kisskh.js` · Sources Forja · Home movies

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-T01 | Stop `list[0]` / dead tmdbID Search match — score normalized title (+ year / movie eps) | ✅ |
| 2 | I369-T02 | Multi-query Search (full title → colon prefix → significant words); omit weak hits | ✅ |
| 3 | I369-T03 | Movie / single-ep dramas: pick episode number 0 or 1 (KissKh movies often use `0`) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I369-A01 | Live Search: Parasite / Dune: Part One / Spider-Man: No Way Home score ≥ 60 on the correct row (not first hit) | ✅ |
| 2 | I369-A02 | Live Drama `4436`: single episode `number: 0` selected for `type=movie` | ✅ |
| 3 | I369-A03 | App: Home → Sources → KissKh lists the matching film (manual) | ⬜ |

---

## Summary

Asian Drama hub injects `kisskhId` via `ctxConfigMap`. **Home / TMDB** has no KissKh id. The provider fell back to `/api/DramaList/Search` and matched `tmdbID` — but **Search never returns tmdbID** — then took **`list[0]`**. Multi-word movie titles return noisy token hits (wrong first row), so Sources looked empty or played the wrong title.

**Root fix:** title-score Search candidates (same idea as hub `hubKisskhPickForRec`), try shorter query variants, require score ≥ 60, and treat movie episode `0` as playable. Providers pack **1.6.19**.

### Related

- [stream providers](../../features/sources/stream-providers.md)
- [asian-drama](../../features/hubs/asian-drama.md)
