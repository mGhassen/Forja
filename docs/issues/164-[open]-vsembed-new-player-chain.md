# 164 — VSEmbed fails: live player left rcp/prorcp HTML chain

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `vidsrc` / VSEmbed · `crates/webstreamr/src/extractors/vidsrc.rs` · `HostProviderAdapter`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I164-T01 | `VidsrcProvider` → `HostRequired`; host tries Rust chain then sniffs `vsembed.su` | ✅ |
| 2 | I164-T02 | `vidsrcExtractProfile`: forceDirect + deferUntilStrongStream (JS/WASM player) | ✅ |
| 3 | I164-T03 | Feature doc + changelog + Simple resolve budget for sniff | ✅ |
| 4 | I164-T04 | Sniff boots `#bigPlay` / injects `CFG.playerUrl` (`autoStart:false` landing) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I164-A01 | Desktop/mobile: VSEmbed plays a title that works on vsembed.su web (e.g. The Amateur) | ⬜ |
| 2 | I164-A02 | Log shows Rust empty → sniff when legacy rcp/prorcp is gone | ⬜ |

---

## Summary

Live VSEmbed iframe now points at `cloudorchestranova.com/embed/movie/…?vs=…` (JS player + vsdec WASM + encrypted `data.vidsrcme.ru` `stream_urls`). Forja’s Rust extractor still expected `#player_iframe` → `/rcp` → `/prorcp` → scrape `file:` / `master_urls`, so resolve returned `no streams` while the browser worked.

**Symptom fix (shipped):** host path tries the legacy Rust chain, then WebView-sniffs `vsembed.su` like other embed providers. Live landing uses `autoStart:false` + `#bigPlay` → nested `/embed/player/…` before `stream_urls`; sniff now force-boots that path (`VS_BOOT` log).

**Root / engine (open):** port the new decrypt + `stream_urls` path into Rust (or shared WASM) so Android TV (no headless WebView) can resolve VSEmbed again without sniff.

## Related

- [047](fixed/047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — vsembed.su + plugin request
- [054](fixed/054-[fixed]-vidsrc-cloudstream-referer-blocks-segments.md) — CloudStream Referer
- [031](031-[workaround]-android-tv-webview-gles-crash.md) — ATV skips HostRequired WebView
