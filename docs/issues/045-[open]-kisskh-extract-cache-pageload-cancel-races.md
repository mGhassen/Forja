# Issue 045 — KissKh extract flaky: cache + page-load wait + cancel races

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `shared/extractors/providers/kisskh/kisskh_extractor.dart`, `shared/player/player/utils.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **10 / 10** fix · **0 / 2** device smoke |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I45-T01 | Disable WebView HTTP cache / incognito for KissKh extract (stale kkey / skipped Episode API) | ✅ |
| 2 | I45-T02 | Stop blocking on `onLoadStop` — wait only for Episode stream API | ✅ |
| 3 | I45-T03 | Serialize resolves + cancel without unhandled `completeError` | ✅ |
| 4 | I45-T04 | Force `Referer: https://kisskh.co/` for KissKh CDN when cache drops headers | ✅ |
| 5 | I45-T05 | Soft-reload + play nudge if Episode API silent | ✅ |
| 6 | I45-T06 | Hard `loadUrl` + cache-bust recovery (replace plain `reload()`); purge kisskh cookies; second recovery at 24s | ✅ |
| 7 | I45-T07 | Expand KissKh CDN Referer fix to `streamingcdn*.site` + per-episode Asian Drama cache keys | ✅ |
| 8 | I45-T08 | Rust mirror health selection + sticky API failover across compatible KissKh domains | ✅ |
| 9 | I45-T09 | Use the Rust-selected mirror for WebView page, cookies, retries, Referer, Origin, and subtitles | ✅ |
| 10 | I45-T10 | Mirror compatibility / failover unit tests and host URL contract tests | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I45-A01 | Backrooms (and a TVSeries title) resolve to `xhr hit` without stuck “Waiting for stream key…” on cold open | ⬜ |
| 2 | I45-A02 | With the active KissKh domain unavailable, catalog and episode extract select another compatible mirror and preserve matching IDs | ⬜ |

---

## Summary

KissKh stream extract opened a **cached** headless WebView, waited up to **35s on page load** before treating the Episode API as primary, and overlapping `resolve`/`cancel` calls raced a single extractor (unhandled `TimeoutException: KissKh extraction cancelled`). Playback header fallback also derived `Referer` from the CDN host (`cdnvideo*.shop`) when cached `StreamSource.headers` were missing — CDNs reject that.

**Symptom:** Loading overlay stuck on “Opening kisskh…” / “Waiting for stream key…”; logs show `page load timeout` and silent Episode API.

**Root:** Extractor lifecycle + WebView cache + wrong CDN Referer fallback — not kisskh.co being down.

### Follow-up (2026-07-15)

Live macOS logs still showed Episode API silent after I45-T05 `reload()` (e.g. re-open Episode-2 → “no Episode API in 12s — soft reload once” with no `xhr hit`). WKWebView `reload()` can reuse the SPA shell / skip UserScript reinjection. Current HLS hosts are `*.streamingcdn*.site`, which I45-T04’s `cdnvideo`/`kisskh` host check missed — cached reopen lost `kisskh.co` Referer. Asian Drama `openPlayer` also omitted season/episode, collapsing every episode onto cache key `S1:E1`.

### Mirror failover slice (2026-07-16)

Live compatibility probes found that `kisskh.co`, `kisskh.nl`, `kisskh.ovh`,
`kisskh.la`, and `kisskh.do` expose the same Angular JSON API and drama IDs.
Other similarly named domains returned unrelated HTML, 404, DNS failure, or a
refused connection and are deliberately excluded. Rust owns health selection
and API failover; the host WebView still owns signed `kkey` extraction but must
use the same selected base URL.

**Shipped:** `crates/kisskh` races the five verified API mirrors, keeps the
first valid response sticky, and retries catalog requests across the remaining
mirrors on HTTP or non-JSON failure. `KissKhExtractor` starts from that selected
host, rotates to another mirror every eight seconds while the Episode API is
silent, and feeds the winning host back to Rust. Page cookies, navigation
headers, playback headers, third-party extraction, and subtitle fetch all use
that winning host.
