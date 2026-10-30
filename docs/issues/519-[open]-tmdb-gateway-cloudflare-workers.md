# 519 — Move TMDB gateway off Vercel onto Cloudflare Workers

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** TMDB gateway · Vercel FDT · Cloudflare Workers · R2  
**Reported:** 2026-10-30 (Vercel Fast Data Transfer still high after image 302→R2; JSON `/3/*` egress)

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 6** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

After `/t/p/*` 302→R2, Vercel Fast Data Transfer still climbs on app use. Dashboard shows ~11 KB average response size and mixed 2XX/3XX — remaining burn is keyless `/3/*` JSON still served through Vercel CDN.

## Root cause

Vercel bills CDN→client bytes (FDT) for every JSON body. Image redirects fixed JPEG proxying; they cannot remove API egress while the gateway stays on Vercel.

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I519-T01 | Cloudflare Worker entry (`src/worker.js`) + `wrangler.toml` (R2 binding, daily cron) | ✅ |
| 2 | I519-T02 | R2 ops via Workers binding (prefer over AWS SDK on edge); public-base redirects | ✅ |
| 3 | I519-T03 | Runtime env bridge so Node local + Worker share `proxy.js` / `cache.js` | ✅ |
| 4 | I519-T04 | README deploy + DNS cutover (`tmdb.forjahq.xyz` → Worker); deprecate Vercel as primary | ✅ |
| 5 | I519-T05 | Keep Node local + unit tests green; Vercel entry left for rollback only | ✅ |
| 6 | I519-T06 | Deploy Worker + point custom domain; smoke `/health`, `/3/*`, `/t/p/*` 302 | ⬜ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I519-A01 | `https://tmdb.forjahq.xyz/health` reports Worker/R2 ready (not Vercel-only) | ⬜ |
| 2 | I519-A02 | Image `curl -sI /t/p/…` → 302 + `X-TMDB-Image-Mode: redirect` | ⬜ |
| 3 | I519-A03 | Home/API JSON works; Vercel project no longer serves production traffic | ⬜ |

## Links

- [302](302-[open]-tmdb-proxy-base-url.md) — gateway product
- Gateway: `apps/tmdb-gateway/`
