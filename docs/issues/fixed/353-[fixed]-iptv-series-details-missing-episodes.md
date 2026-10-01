# 353 — IPTV series details missing seasons / episodes list

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** IPTV · series details · `EngineService.runCatalog` · `meta.videos`  
**Reported:** 2026-09-24  
**Related:** [236](236-[fixed]-live-sports-feed-empty-enginejs.md) · [162](162-[open]-iptv-more-like-this-catalog-only.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I353-T01 | Add `details` to portal `hostBridgeActions` so IPTV details runs on flutter_js (vault + http/engine) | ✅ |
| 2 | I353-T02 | Document `needsPortalPackHost` includes details (episode fetch) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I353-A01 | Open IPTV Series title with portal episodes — season/episode picker appears under the hero (not only Cast) | ⬜ |
| 2 | I353-A02 | Logs: `iptv-hub details` uses `needs http+vault+playback — flutter_js` (not `enginejs live` ~20ms empty) | ⬜ |

---

## Summary

IPTV series details showed TMDB Cast and **Seasons / Episodes** fact counts, but no interactive episode list. The picker mounts only when `meta.videos` is non-empty (`PackDetailsHost`). Counts come from TMDB enrich `facts`, independent of portal episodes.

**Root:** `runCatalog` ran IPTV `details` on EngineJS-first. EngineJS has no vault/http bridge, so `iptvFindPortalByKey` / `series_episodes` never ran — details returned a valid empty-videos envelope in ~20ms and never fell through to flutter_js. Same class of bug as [236](236-[fixed]-live-sports-feed-empty-enginejs.md) (host-bridge action left off the allowlist).

**Fix:** Include `details` in `hostBridgeActions` for `needsHostBridge` plugins (IPTV). Feed already used the bridge; details now does too.
