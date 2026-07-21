# 091 — Simple resolve budgets kill WebStreamr + embed servers

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/playback/simple_streaming_resolve.dart`, `apps/forja/lib/shared/extractors/core/stream_extractor.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix · **0 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I91-T01 | Per-provider Simple resolve budgets: VSEmbed 25s · WebStreamr 90s · host API 35s · embed sniff 75s (was 25/12) | ✅ |
| 2 | I91-T02 | Headless WebView `_cleanup`: null-out + timed dispose (2s) so WKWebView hang cannot strand CHECKING | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I91-A01 | Pin WebStreamr on green Play (Simple resolve on) — loading reaches UP with streams (not empty/timeout at ~25s) | ⬜ |
| 2 | I91-A02 | Pin a template embed (e.g. VidLink / VidSrc.sbs) — CHECKING finishes within sniff budget (not hard-fail at ~12s) | ⬜ |
| 3 | I91-A03 | macOS: after a failed/cancelled sniff, next server check still starts (dispose does not hang forever) | ⬜ |

---

## Summary

Simple resolve is **default on**. Its old hard budgets were:

- **25s** for every native (`vidsrc` + `webstreamr`)
- **12s** for every host (Videasy, VidLink, VidSrc.sbs, …)

VSEmbed finishes in a few seconds. WebStreamr’s multi-source scrape often needs longer than 25s → timeout → `cancelAllPending` → empty. Template embeds need 45–60s WebView sniff → killed at 12s → DOWN. Symptom: **only VSEmbed works**; WebStreamr / other servers look empty. On macOS, unbounded `HeadlessInAppWebView.dispose()` in `StreamExtractor._cleanup` could also leave CHECKING forever after a sniff.

**Root fix:** match budgets to real work (WebStreamr / embed profiles) and never await dispose without a timeout.

## Related

- [RFC-038](../rfc/038-[open]-simple-streaming-resolve.md) — Simple resolve path
- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — sniff quality (separate from budget knife)
- [037](037-[open]-webstreaming-all-providers-open-validate.md) — probe-before-open
- [direct streaming / webstreaming](../features/movies-tv/direct-streaming-mode.md)
