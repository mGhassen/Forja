# 342 — NetMirror empty / wrong-episode Sources

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/netmirror.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **2 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I342-T01 | Live probe: confirm embed-tmdb ignores `s`/`e` (always S1E1) and honors `se`/`ep` | ✅ |
| 2 | I342-T02 | Switch TV embed query to `se`/`ep`; treat `ok`+error / empty streams as miss | ✅ |
| 3 | I342-T03 | Fail-fast NewTV discovery (`check.php` + short parallel `checknewtv`); accept `otp` player links | ✅ |
| 4 | I342-T04 | Providers pack 1.6.12 + feature/changelog docs + host regression assert | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I342-A01 | curl: `embed-tmdb/1396?type=tv&se=3&ep=7` → `currentSeason=3` / `currentEpisode=7` with streams; `s=3&e=7` stays S1E1 | ✅ |
| 2 | I342-A02 | curl: movie `27205` embed returns ≥1 stream URL with `videodownloader.site` Referer → CDN 200 | ✅ |
| 3 | I342-A03 | App: Sources → NetMirror lists correct-episode streams (manual) | ⬜ |

---

## Summary

NetMirror Forja’s primary path (`net27.cc/api/embed-tmdb`) is live, but TV requests used `?s=&e=`. The API **ignores** those params and always returns **S1E1**. Wrong-episode (or empty) rows looked like “no streams.”

NewTV fallback discovery via `checknewtv.php` still resolves to **`tv.imgcdn.kim`**, which times out / 522. Walking every detect host sequentially burned extract time after an embed miss.

### Fix

- TV embed: `?type=tv&se={season}&ep={episode}`
- Treat `ok:true` with `error` / no `streams` / no `mp4` as miss
- Discover NewTV via `check.php` (app) + short parallel `checknewtv` (first few hosts only)
- Accept player `video_link` even when `status` is not `ok` (e.g. `otp`)
- Providers pack **1.6.12**

### Related

- [stream providers](../../features/sources/stream-providers.md)
- Changelog 1.4.128 — earlier net27 embed + `otp` accept (NewTV discovery regressed again)
