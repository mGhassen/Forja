# 406 — 2DHive Sources empty (stale HAdfree scrape)

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/2dhive.js` · Anime Sources · 2DHive

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 2 / 2** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I406-T01 | Scrape Wavy HLS (`wavy.babastream.top`) with episode Referer | ✅ |
| 2 | I406-T02 | Scrape Megaplay `getSources` inline (hop was never wired) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I406-A01 | Anime → Black Clover E1 → 2DHive lists a playable Wavy and/or Megaplay stream | ⬜ |

---

## Summary

2DHive’s site no longer ships HAdfree / `prefetchedHls` / `/api/hianime`. The extractor still targeted those, hopped Megaplay with no hop plugin, and returned zero streams. Current servers are BabaStream (Cap challenge — omitted), Megaplay, and Wavy native HLS.

**Root fix:** visit `wavy.babastream.top/{mal}/{ep}/{sub|dub}` then play the HLS variant with that Referer; also scrape Megaplay `getSources` in-process. Providers pack **1.6.31**.
