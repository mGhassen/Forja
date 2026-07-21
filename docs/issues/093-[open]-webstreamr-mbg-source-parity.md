# 093 — WebStreamr local scrape out of sync with WebStreamrMBG

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/webstreamr`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I93-T01 | Sync `ALL_SOURCES` bases to WebStreamrMBG (`vidsrcme.ru`, `megakino2.biz`, HDHub4u limo, Movix/Frembed/CineHDPlus/4KHDHub, …) | ✅ |
| 2 | I93-T02 | Add missing MBG sources + extractors: VidZee, MovieBox, Filmpalast; decouple VSEmbed host from WebStreamr `vidsrc` | ✅ |
| 3 | I93-T03 | HDHub4u search → `search.hdhub4u.glass`; keep legacy Forja-only sources (rgshows/streamkiste/vegamovies) | ✅ |
| 4 | I93-T04 | Forward migration: remote `provider_runtime_config.webstreamr` bases → MBG hosts (+ vidzee/moviebox/filmpalast) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I93-A01 | Pin WebStreamr on a popular film — stream titles include MBG-style sources (VidSrc / MegaKino / VidZee / MovieBox when available) | ⬜ |
| 2 | I93-A02 | VSEmbed standalone still uses `vsembed.su` (not `vidsrcme.ru`) | ⬜ |

---

## Summary

Forja’s Rust WebStreamr was a **stale port** of the [WebStreamrMBG](https://github.com/newman2x/WebStreamrMBG) / [webstreamr](https://github.com/webstreamr/webstreamr) scraper tree — not a call to the Beamup Stremio addon. Dead bases + missing MovieBox / VidZee / Filmpalast made lists diverge and many streams fail.

**Root fix:** align source bases + add missing source/extractor modules from MBG `src/source` + `src/extractor`. VSEmbed (`api.vidsrcEmbed` / `vsembed.su`) stays separate from WebStreamr’s `vidsrc` (`vidsrcme.ru`).

**Also:** hosted `provider_runtime_config` still had pre-MBG bases (`vsembed.su`, `megakino1.to`, …). Remote overlay merges **on top** of builtins and would undo the Rust defaults until migration `20260721140236_provider_runtime_webstreamr_mbg_bases` is applied (needs explicit `db push` approval).

## Related

- [WebStreamr sources](../features/scrapers/webstreamr-sources.md)
- [047](fixed/047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — VSEmbed host (must stay decoupled)
- Upstream: https://github.com/newman2x/WebStreamrMBG
- Migration: `apps/web/supabase/migrations/20260721140236_provider_runtime_webstreamr_mbg_bases.sql`