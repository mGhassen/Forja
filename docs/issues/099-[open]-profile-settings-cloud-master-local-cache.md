# 099 — Profile settings: cloud is master, local file is cache

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** sync (`SyncDomainBridge` / `profile_settings`)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I99-T01 | Merge push into existing cloud payload — never drop remote keys because local export omitted them | ✅ |
| 2 | I99-T02 | Empty local Stremio/Nuvio export must not wipe cloud unless that domain scheduled the push | ✅ |
| 3 | I99-T03 | Local reset / pull apply always cancels pending pushes (cache-only; no push-from-wipe) | ✅ |
| 4 | I99-T04 | Sync `preferred_subtitle_lang` in playback export/import/reset | ✅ |
| 5 | I99-T05 | Feature docs + changelog: cloud master for profile_settings | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I99-A01 | Toggle playback pref with empty local Stremio cache — cloud Stremio addons unchanged | ⬜ |
| 2 | I99-A02 | Preferred subtitle survives restart + pulls across devices when signed in | ⬜ |

---

## Summary

Same product rule as [096](fixed/096-[fixed]-iptv-empty-local-cache-wipes-cloud.md) for IPTV: **cloud is master**; `forja_engine_store.json` is a **cache**. Intentional UI edits write the cache and push to cloud. Wipe / pull / defaults must never push empty or incomplete local state over a populated cloud row.

**Before:** `pushAllLocal` built a lean payload from local only and **replaced** `profile_settings.payload`. Missing local keys (empty Stremio, omitted subtitle) could delete cloud data. Preferred subtitle was local-only.

**After:** Pull remote first, overlay intentional local domains, refuse empty connected-service wipe unless that domain’s debounce fired; cancel pending pushes on local reset; subtitle in playback blob.
