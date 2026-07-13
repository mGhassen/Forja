# 036 — Vidsrc CDN host hardcoded to dead cloudnestra.com

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/webstreamr/src/extractors/vidsrc.rs`, Vidsrc provider, WebStreamr VidSrc extractor path

## Status at a glance

| | |
|--|--|
| **Progress** | **2 / 2** fix tasks · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I36-T01 | Derive CDN host from rcp iframe URL for `/prorcp/` resolution, `{vN}` m3u8 placeholders, and playback Referer/Origin | ✅ |
| 2 | I36-T02 | Refresh golden fixtures/tests (`cloudorchestranova.com`); keep legacy `cloudnestra.com` regression test | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I36-A01 | `resolve_vidsrc_embed_json` for TMDB `104359` S1E1 reaches prorcp on live CDN host (not `cloudnestra.com`) | ✅ |
| 2 | I36-A02 | WebStreamr `run_vidsrc_extractor` passes rcp URL into chain JSON helper | ✅ |

---

## Summary

VidSrc embed pages (`vsembed.ru` / `vidsrc-embed.ru`) iframe into a CDN such as **`cloudorchestranova.com`**. The Rust chain hardcoded **`cloudnestra.com`** when resolving relative `/prorcp/…` paths and `{v1}` stream host placeholders. `cloudnestra.com` no longer serves prorcp pages, so dedicated **Vidsrc** and WebStreamr VidSrc-style extraction failed after the CDN rename.

## Root cause (historical)

`DEFAULT_HOST = "cloudnestra.com"` in [`vidsrc.rs`](../../../crates/webstreamr/src/extractors/vidsrc.rs) ignored the host from the live rcp iframe.

## Fix (shipped)

- Parse CDN host from the rcp iframe URL (`find_prorcp_url(rcp_html, rcp_url)`).
- Use that host for m3u8 `{vN}` substitution and response `Referer`/`Origin` headers.
- `extract_vidsrc_chain_json(..., rcp_url: Option<&str>)` falls back to outer iframe when `rcp_url` is omitted (FFI parity tests).

### Follow-up (same issue — VidSrc player format change)

VidSrc prorcp pages moved from `file: "…m3u8"` to `var master_urls = "…master.m3u8?token=__TOKEN__ or …"`. Shipped:

- Parse `master_urls`, fetch JWT from each CDN host’s `/generate.php`, substitute `__TOKEN__` / `__TOKENPG__`.
- WebStreamr fallback: count only **playable** `multi` results when deciding whether to run VidSrc (`use_only_with_max_urls_found: 0`) — failed scraper rows no longer block VidSrc.
- Match `vsembed` host for the VidSrc extractor registry.

## Verify

```bash
cd crates && cargo test -p webstreamr vidsrc::tests --lib
```

Live chain (curl): `vsembed.ru/embed/tv/104359/1-1` → `cloudorchestranova.com/rcp/…` → `/prorcp/…` → m3u8 `file:` in HTML.

## Related

- [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) — isolate offload (separate from CDN host)
- [Stream providers](../../features/sources/stream-providers.md)
