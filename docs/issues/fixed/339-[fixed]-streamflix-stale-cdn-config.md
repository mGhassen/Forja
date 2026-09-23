# 339 — StreamFlix empty Sources (stale CDN config)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/streamflix.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I339-T01 | Probe live API — `config-streamflixapp.json` CDNs dead (Wasabi 404, `bb`/`cf` DNS fail); `config-streamflix2.json` → `s1`/`s2`/`s3.streamflixserver.site` movies HEAD 200 | ✅ |
| 2 | I339-T02 | Switch extract to `config-streamflix2.json`; unique bases from premium/movies/tv/download | ✅ |
| 3 | I339-T03 | Providers pack bump + changelog + host string test | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I339-A01 | Live probe: John Wick 4 / Oppenheimer movielink on s1–s3 returns HTTP 200 matroska | ✅ |
| 2 | I339-A02 | App: Sources → StreamFlix lists playable movie streams (manual) | ⬜ |

---

## Summary

StreamFlix catalog (`/data.json`) still matches TMDB ids, but extract built play URLs from **`config-streamflixapp.json`**. Those bases are dead (`bb.streamflixserver.site` / `cf.streamflixserver.site` DNS fail; Wasabi bucket 404). Host HTTP-probes before open, so Sources never got a working StreamFlix stream.

The live app config is **`config-streamflix2.json`** (`s1` / `s2` / `s3.streamflixserver.site`). Movie paths (`movielink`) HEAD 200 there.

### Fix

- Read `/config/config-streamflix2.json` (override via `configPath`)
- Deduplicate CDN bases across `premium` / `movies` / `tv` / `download`
- Providers pack **1.6.10**

### Known gap (upstream)

TV episode paths (`tv/{moviekey}/s{N}/episode{M}.mkv`) still **404** on the new CDN across sampled shows. StreamFlix’s own config notice says playback issues are being worked on. Extract still emits the historical TV path when a catalog match exists; movies are restored.

### Related

- [stream providers](../../features/sources/stream-providers.md)
- [RFC-060](../../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
