# 080 — Miruro CF pipe unlock fails while site works in browser

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/features/anime/catalog/miruro_pipe_session.dart`, `crates/anime/src/extractors/miruro.rs`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 7** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I80-T01 | Rust pipe: network send errors → `cf_blocked` (WebView) instead of hard `Err` | ✅ |
| 2 | I80-T02 | Prefer `miruro.tv` primary; domain failover on WebView boot / pipe fetch | ✅ |
| 3 | I80-T03 | MiruroPipe boot: progress≥90, fail-fast on cancel/dispose, CF clearance poll | ✅ |
| 4 | I80-T04 | Hot-reload / macOS smoke: anime ep resolve via Miruro servers | ⬜ |
| 5 | I80-T05 | Feature tip / changelog: Miruro CF unlock reliability | ✅ |
| 6 | I80-T06 | CF wait: empty title / blank doc ≠ cleared; JS bridge errors keep polling (no early abort) | ✅ |
| 7 | I80-T07 | Boot: no markReady on main-frame error / mid-challenge progress; longer CF wait (25s) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I80-A01 | Manual: play anime ep — at least one Miruro server (bee/bonk/hop/kiwi) resolves | ⬜ |
| 2 | I80-A02 | Logs: no 35s `MiruroPipe boot failed` TimeoutException on cold play | ⬜ |
| 3 | I80-A03 | Connection errors to `miruro.*` trigger WebView pipe, not only thrown `error sending request` | ⬜ |

---

## Summary

[miruro.tv](https://www.miruro.tv/watch/21/one-piece?ep=1) works in a normal browser (all servers). Forja failed because:

1. **Rust `reqwest`** cannot clear Cloudflare — pipe returns 403 HTML, or often fails earlier with `error sending request for url (…)`. The old `?` on `anime_get` turned send failures into hard errors, so Dart never entered the WebView CF fallback.
2. **`MiruroPipeSession`** boot waited only on `onLoadStop` (35s). CF challenge pages on macOS headless WKWebView often stall; `cancelPending` disposed the WebView without completing the waiter, so boot hung until timeout.
3. Primary domain was `.to`; public site users open is `.tv` (same CF, but we now prefer `.tv` and fail over).
4. **False CF clear (I80-T06):** blank documents (`title=""`, `blocked:false`) and JS bridge “unsupported type” errors aborted the wait early → pipe `403` while the real browser still works. Empty title stays “blocked”; catch no longer returns.
5. **Boot false-ready (I80-T07):** `onReceivedError` / progress≥90 marked the waiter ready on a broken CF page. Only loadStop / progress=100 unblock; CF poll waits up to 25s.

**Not fixed here:** VidNest `new.vidnest.fun` returning **502** — upstream outage, separate from Miruro. Megaplay `nekostream` Referer — [084](084-[open]-megaplay-nekostream-cdn-referer.md).

## Related

- [075](fixed/075-[fixed]-anime-dead-cache-empty-sources.md) — anime dead-cache / Miruro cancel interaction
- [084](084-[open]-megaplay-nekostream-cdn-referer.md) — Megaplay nekostream CDN Referer
- [anime hub](../features/hubs/anime.md)
