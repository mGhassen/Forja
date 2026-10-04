# 408 — Senshi Sources empty (site moved to senshi.to)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/senshi.js` · Anime Sources · Senshi

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 1 / 1** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-T01 | Point Senshi `base` at `https://senshi.to` (`episode-embeds` API unchanged) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-A01 | Anime → a MAL-mapped title → Senshi lists a playable Sub/Dub/Raw stream | ⬜ |

---

## Summary

Senshi moved from `senshi.live` to [senshi.to](https://senshi.to/). The old host fails TLS. `/episode-embeds/{mal}/{ep}` still returns the same JSON on the new host.

**Root fix:** `SPECS.base` is `https://senshi.to`. Referer/Origin follow that base. Providers pack **1.6.33**.
