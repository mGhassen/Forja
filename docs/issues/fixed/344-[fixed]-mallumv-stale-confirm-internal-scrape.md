# 344 — MalluMV empty Sources (stale /confirm/ scrape)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/mallumv.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I344-T01 | Replace MalluMV `/confirm/` chain with live `search.php` → `/movie/` → `/internal/` → Pixeldrain / HubCloud (same path as DVDPlay) | ✅ |
| 2 | I344-T02 | Encode spaced `/internal/…` paths; resolve HubCloud `/video/` → `hubcloud.php` file hosts | ✅ |
| 3 | I344-T03 | Providers pack 1.6.14 + feature/changelog docs + host smoke asserts | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I344-A01 | curl: Premalu movie page lists `/internal/` rows (0 `/confirm/`); internal page yields `pixeldrain.dev` + `hubcloud.ist` | ✅ |
| 2 | I344-A02 | curl: HubCloud video page exposes `hubcloud.php` generate link | ✅ |
| 3 | I344-A03 | App: Sources → MalluMV lists streams for a title that previously returned 0 (manual) | ⬜ |

---

## Summary

Issue [343](343-[fixed]-dvdplay-dead-xyz-mallumv-space.md) retargeted MalluMV’s base to `mallumv.space` but left the old Nuvio scrape: movie pages → `/confirm/` → `/internal/`. Live title pages link **directly** to `/internal/…` quality rows (spaces in the path). MalluMV found the movie, then extracted 0 download links and returned empty Sources.

**Root fix:** clone the working DVDPlay extract path (search → internal → Pixeldrain / HubCloud), branded MalluMV. Not a workaround.

### Related

- [343 DVDPlay / mallumv.space](343-[fixed]-dvdplay-dead-xyz-mallumv-space.md)
- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
- [stream providers](../../features/sources/stream-providers.md)
