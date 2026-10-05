# 416 — CineSrc / CineSu / Bcine: `glendale-plumbing` CDN dead, site moved behind a challenge gate

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/cinesrc.js` · `cinesu.js` · `bcine.js` · Movies & TV Sources

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 3** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I416-T01 | Pick the minting path: port the cinesrc challenge to QuickJS, or add a host WebView sniff capability for HTTP packs | ✅ |
| 2 | I416-T02 | CineSrc returns a playable `cinesrc.st/api/playlist/…` master for movie and TV | ⬜ |
| 3 | I416-T03 | CineSu and Bcine: re-point to the same flow or to their own live mirrors (bcine.ru now redirects to cineyz.com) | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I416-A01 | Manual: Fight Club (TMDB 550) via CineSrc opens and plays in the desktop player (no `switch probe failed`) | ⬜ |

---

## Summary

Player log: `[Player] Forja switch failed: switch probe failed: https://glendale-plumbing.com/c/v1/…/master.m3u8?_v=34403446`.

The three providers build the URL locally (`nD` / `aD` keyed encoder → `glendale-plumbing.com/c/v1/<id>/master.m3u8`). The host probe rejects it correctly:

- With the `cine.su` Referer, Cloudflare passes the request and answers **523 origin unreachable**. Every title tested (550, 27205, 603) gets 523 or times out.
- With the `cinesrc.st` or `bcine.ru` Referer the CDN answers 403.

## What cinesrc.st does now

Captured in headless Chrome on `https://cinesrc.st/embed/movie/550`:

1. `POST /api/c/bootstrap` (`x-cs-q` = base64url `["movie","550",null,null]`) → `{r, p}`
2. `GET /api/c/issue` (PoW: `w, t, n, s`, solved by `/pow-worker-v3.js` + `/pow-v3.wasm`)
3. `GET /api/c/stage2/issue` → bytecode `pack` run by `/donut.js` (custom VM)
4. `GET /api/c/pk` → RSA public key
5. Next.js server action `getStream(tmdbId, "movie"|"show", season, episode, "s1~<token>", providerId)` → `r3.<…>` sealed payload, decoded client-side by `/300726c-prod.js` (`dr`)
6. Result: `https://cinesrc.st/api/playlist/<token>.m3u8` (master) → variants → segments on `nebula.bright67.online`

All three scripts are fully obfuscated (string tables, VM, WASM). `300726c` reads as a build tag, so it rotates.

The minted master URL is **not** session-bound: curl with no headers plays it, still valid after 120 s. Segments are open. Only minting needs the challenge.

## Options

- **QuickJS port:** deobfuscate the VM + PoW + `dr`. QuickJS has no WASM or DOM. Days of work; breaks on each rotation.
- **Host WebView sniff:** pack returns the embed URL with a capture pattern (`/api/playlist/`); host loads it headless and hands the first master URL to the player. ~7 s to first playlist in Chrome. Reverses the `StreamExtractor` removal (commit `a4ac2d0cf`). No headless WebView on Linux.

## Decision

QuickJS port chosen (2026-10-06). Work paused before any pack change: running the challenge against the live site needs the owner's explicit go-ahead in the agent session.

## Related

- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — earlier generic embed sniff (removed)
- [170](170-[open]-vidzee-cloudflare-sniff.md) — Vidzee Cloudflare sniff
