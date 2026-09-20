# Issue 302: Forja TMDB gateway (pack-owned)

**Status:** open  
**Priority:** P2  
**Severity:** Medium  
**Area:** TMDB · Home pack · enrich hubs · providers · host · regional access

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 11** fix · **2 / 5** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Problem

Direct `api.themoviedb.org` is blocked or flaky in some regions. Home already owns TMDB via pack `config.base` (was third-party `db.speedracelight.com`). Need a Forja-owned keyless gateway with shared Supabase cache, plus enrich hubs, stream providers, and host TMDB helpers on the same gateway — not only Rust `crates/tmdb`.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I302-T01 | Sibling `tmdb-proxy` catch-all spike (superseded by apps/tmdb-gateway) | ✅ |
| 2 | I302-T02 | `crates/tmdb` `TMDB_BASE_URL` (legacy host path — not product) | ✅ |
| 3 | I302-T03 | Local smoke of early proxy endpoints | ✅ |
| 4 | I302-T04 | Hub enrich kits prefer `cfg.base` + `ctx.fetch` (not Rust `host.tmdb` first) | ✅ |
| 5 | I302-T05 | `apps/tmdb-gateway` — keyless `/3/*` + `/t/p/*`, config image rewrite, Vercel + local, no Express | ✅ |
| 6 | I302-T06 | Supabase `tmdb_response_cache` (JSON) + `tmdb_image_cache` / Storage `tmdb-images` | ✅ |
| 7 | I302-T07 | Home + enrich packs point `base` / `imageBase` at `https://tmdb.forjahq.xyz` | ✅ |
| 8 | I302-T08 | Deploy Vercel + custom domain `tmdb.forjahq.xyz`; apply migrations on hosted Supabase | ⬜ |
| 9 | I302-T09 | Gateway images use Storage (not Postgres bytea) | ✅ |
| 10 | I302-T10 | Stream providers + Live Sports / cover helpers use gateway API + image hosts | ✅ |
| 11 | I302-T11 | Host `crates/tmdb` + Dart image bases + `host.tmdb` inject default to gateway (keyless) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I302-A01 | Legacy: Rust `TMDB_BASE_URL` local smoke | ✅ |
| 2 | I302-A02 | Local gateway: `/health`, `/3/movie/550`, `/t/p/…` return OK | ✅ |
| 3 | I302-A03 | Home feed/search/details via gateway `cfg.base` (no Rust rebuild) | ⬜ |
| 4 | I302-A04 | Pack unset / official API still works when `base` is `api.themoviedb.org` + apiKey | ⬜ |
| 5 | I302-A05 | Provider metadata fetch (e.g. VidLink / MovieBlast) hits `tmdb.forjahq.xyz` | ⬜ |

---

## Notes

- Gateway: [`apps/tmdb-gateway/`](../../apps/tmdb-gateway/) — env from Forja `.env` + `SUPABASE_SERVICE_ROLE_KEY` + `TMDB_GATEWAY_PUBLIC_URL`
- Migration: `*_tmdb_response_cache.sql` (JSON) + `*_tmdb_image_storage_cache.sql` (Storage bucket + meta) — create only; apply needs ops approval
- Images: Storage bucket `tmdb-images`; JSON: Postgres `tmdb_response_cache`
- Out of scope this slice: Arabic / Aflem / Shahid hub packs (feature scope)
