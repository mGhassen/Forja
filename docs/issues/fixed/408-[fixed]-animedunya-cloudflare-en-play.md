# 408 — AnimeDunya Sources empty (Cloudflare on `/en/play`)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/animedunya.js` · Anime Sources · AnimeDunya

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-T01 | Fetch play HTML from `/api/play/{mal}/{ep}` (Cloudflare skips this locale path) | ✅ |
| 2 | I408-T02 | Fall back to `/en/play/` with Chrome TLS; parse Next.js flight `stream` object | ✅ |
| 3 | I408-T03 | Providers pack bump + changelog | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I408-A01 | Anime → Black Clover E1 → AnimeDunya lists a playable HLS stream | ⬜ |

---

## Summary

AnimeDunya extract hit `https://anime-dunya.com/en/play/{mal}/{ep}`. Cloudflare’s managed challenge returns 403/429 (`Just a moment…`) on that locale in ~800ms, so the flight payload never arrived and Sources stayed empty. The same Next.js page at `/api/play/{mal}/{ep}` (`api` as locale) returns the HTML with `"stream":{ "source": "https://fs2.anime-dunya.com/files/…/master.m3u8" }` without the challenge.

**Root fix:** load `/api/play/` first, Chrome TLS, then `/en/play/` if that body is a challenge. Providers pack **1.6.30**.

### Related

- [405](405-[fixed]-reanime-flixcloud-cf-false-positive.md) — Cloudflare interstitial vs real payload
