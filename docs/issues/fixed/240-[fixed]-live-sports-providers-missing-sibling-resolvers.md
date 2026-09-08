# 240 — Live Sports Providers missing sibling resolvers

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** Live Sports · Providers panel · `LiveResolveStreams`  
**Reported:** 2026-09-08  
**Related:** [073](../rfc/fixed/073-[fixed]-live-sports-kit-ownership.md) · [223](223-[fixed]-live-streamic-raw-embed-format-fail.md)

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I240-T01 | Soft-match same fixture across Forja Live catalogs and resolve every sibling plugin | ✅ |
| 2 | I240-T02 | Warm/reuse all-catalog schedule pool for sibling lookup (no empty single-row resolve) | ✅ |
| 3 | I240-T03 | Run Stremio soft-match in parallel with a short grace so hung `getStreams` cannot strand the panel | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I240-A01 | Manual: tap a multi-catalog event — Providers lists streams from more than one Forja Live plugin when siblings exist | ⬜ |
| 2 | I240-A02 | Manual: when Streamed unlock fails but Stremio/other plugins hang, Forja rows still appear within a few seconds | ⬜ |

---

## Summary

**Symptom:** Tapping a Live Sports event showed an empty or incomplete Providers panel. Logs only ran `live-streamed` resolve, then Stremio catalog/`getStreams` with no panel paint.

**Root cause:** Kit `LiveResolveStreams.loadProviders` resolved **only the clicked row** (`single-row, no sibling merge`). Pre-kit Live Matches soft-matched the same fixture across catalogs and unlocked every sibling plugin. Stremio soft-match also ran **after** Forja and could hang the whole `loadTab` await on `getStreams`.

**Fix:** Soft-match siblings from the all-catalog schedule pool (or a fresh All feed), resolve each sibling with its own `livePluginId`, synthesize missing `sources[]` when needed, and overlap Stremio with a short timeout so Forja rows are not stranded.
