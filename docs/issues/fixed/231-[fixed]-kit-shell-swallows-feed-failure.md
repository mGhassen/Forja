# 231 — KitShell swallows hub feed failure (blank Anime hub)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** KitShell · catalog hubs · Anime / AniList

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I231-T01 | On pack `feed` failure: toast “Server is down” + Refresh action (force tab refresh) | ✅ |
| 2 | I231-T02 | Keep hub page structure (hero/rails skeletons) — do not replace the page with an error panel | ✅ |
| 3 | I231-T03 | Bump rail reload token on invalidate so Refresh actually refetches KitSections | ✅ |
| 4 | I231-T04 | Re-tap active nav tab forces hub reload | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I231-A01 | Feed down: mood/layout stay; hero+rails hold skeleton; toast with Refresh reloads; re-tap Anime tab reloads | ⬜ |

---

## Summary

Installing Anime and opening the hub showed vibe chips over a black void. Pack `layout` is static; `feed`/`rail` failures were swallowed as empty pages (no toast, no refresh, sections shrunk).

**Symptom fix:** toast + Refresh; hold empty structure as skeletons; reload epoch so Refresh works; same-tab nav re-tap forces refresh.

**Note:** `graphql.anilist.co` can return 403 while anilist.co website still loads — site ≠ API.

## Related

- [features/hubs/anime.md](../../features/hubs/anime.md)
- [RFC-070](../../rfc/070-[partial]-catalog-hub-protocol.md)
