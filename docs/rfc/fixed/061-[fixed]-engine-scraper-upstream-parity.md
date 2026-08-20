# RFC-061: Engine scraper upstream parity

**Status:** fixed  
**Depends on:** [RFC-060](060-[fixed]-enginejs-sources-forja-tab.md)  
**Area:** `apps/forja/assets/providers/`, Sources Forja tab

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** components · **10 / 12** acceptance · **2 ⏭️** manual play QA |
| **Current slice** | Upstream Anivault / Miru / MiruroAPI parity shipped (`engine.json` 1.5.4) — live play deferred |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R61-C01 | Batch 1: kisskh / senshi / animepahe parity fixes | ✅ |
| 2 | R61-C02 | Batch 2: anikoto / reanime / hianime watch-path ports | ✅ |
| 3 | R61-C03 | Batch 3: animeheaven / anidao / aniwaves new plugins | ✅ |
| 4 | R61-C04 | Batch 4: miruro.js pipe client + Dart `decodePipe` bridge | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R61-A01 | Audit matrix documented (this RFC) for Anivault + Miru overlaps | ✅ |
| 2 | R61-A02 | `kisskh.js` defaults to `kisskh.co`; `.png` without kkey then kkey fallback | ✅ |
| 3 | R61-A03 | `senshi.js` uses senshi.live Referer + sub/dub/raw typing from Anivault | ✅ |
| 4 | R61-A04 | `animepahe.js` uses live base (`.pw`) + `kwik.si` embeds; proxy remains fallback | ✅ |
| 5 | R61-A05 | `anikoto.js` ports Kiwi mapper mirrors + Megaplay/mewstream rewrite | ✅ |
| 6 | R61-A06 | `reanime.js` / `hianime.js` pick up upstream embed/referer fixes | ✅ |
| 7 | R61-A07 | `animeheaven.js` + `anidao.js` + `aniwaves.js` in `engine.json` | ✅ |
| 8 | R61-A08 | `miruro.js` Sources pipe client with HLS preference + per-stream referer | ✅ |
| 9 | R61-A09 | `engine_test.dart` covers new/updated entries + content checks | ✅ |
| 10 | R61-A10 | Feature doc + changelog Sources bullets | ✅ |
| 11 | R61-A11 | Manual: Forja Senshi / AnimePahe / Anikoto rows resolve | ⏭️ |
| 12 | R61-A12 | Manual: Forja AnimeHeaven / Miruro rows play when upstream is up | ⏭️ |

---

## Summary

Use [SH0MIK/Anivault-Scraper](https://github.com/SH0MIK/Anivault-Scraper), [miru-project/repo](https://github.com/miru-project/repo) KissKh/AnimePahe/HiAnime extensions, and [Shineii86/MiruroAPI](https://github.com/Shineii86/MiruroAPI) pipe helpers as **reference scrapers** — port logic into bundled `extract(ctx)` plugins. Do **not** call hosted Anivault/MiruroAPI backends.

### Audit matrix

| Provider | Forja | Upstream | Action |
|----------|-------|----------|--------|
| KissKh | `kisskh.js` | Miru `kisskh.co.js` | Fixed: `.co` + kkey fallback |
| AnimePahe | `animepahe.js` | Anivault `.pw` + Miru `kwik.si` | Fixed: base + kwik + direct-then-proxy |
| Senshi | `senshi.js` | Anivault `senshi.ts` | Fixed: Referer + sub/dub/raw |
| Anikoto | `anikoto.js` | Anivault Kiwi + Megaplay rewrite | Fixed: mapper mirrors + mewstream |
| ReAnime | `reanime.js` | Anivault sidecar (not portable) | Hardened: dataLink / data-an-video |
| HiAnime | `hianime.js` | Anivault Megaplay mirrors | Fixed: vidtube + mewstream rewrite |
| AnimeHeaven | — | Anivault `animeheaven.ts` | **Added** |
| AniDao | — | Anivault `anidao.ts` | **Added** |
| AniWaves | — | Anivault `aniwaves.ts` | **Added** |
| Miruro | Anime tab Rust only | Anivault + MiruroAPI pipe | **Added** Sources plugin + Dart bridge |

**Honesty:** Senshi remains CF-gated (no FlareSolverr). Miruro pipe may 403 without browser clearance. Manual play QA is deferred (R61-A11/A12).

### Related

- [RFC-060](060-[fixed]-enginejs-sources-forja-tab.md)
- [Issue 080](../../issues/080-[open]-miruro-cf-pipe-webview-unlock.md) — Anime tab Miruro WebView (out of scope here)
- [stream-providers](../../features/sources/stream-providers.md)
