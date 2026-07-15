# 054 — Vidsrc CloudStream: Referer/Origin blocks HLS segments

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/webstreamr` Vidsrc extract · `resolvePlaybackHttpHeaders` · player open

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I54-T01 | Vidsrc extract playback headers: User-Agent only (no Referer/Origin) | ✅ |
| 2 | I54-T02 | HeaderManager vidsrc defaults: drop Referer | ✅ |
| 3 | I54-T03 | `resolvePlaybackHttpHeaders`: strip + never derive Referer/Origin for `/pl/…m3u8?token=` CloudStream URLs | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I54-A01 | Curl: CloudStream `page-N.html` segment 200 without Referer; 403 with CDN Referer/Origin | ✅ |
| 2 | I54-A02 | Unit: Dart header helper + Rust chain JSON omit Referer/Origin | ✅ |
| 3 | I54-A03 | App: Vidsrc HOTD S1E1 opens and advances past buffer (manual) | ⬜ |

---

## Summary

Vidsrc finds a valid `master.m3u8` (playlist + variants return 200), but mpv stays buffering / fails open. Browser “works” because embed players fetch segments with **no-referrer**.

### Root cause

CloudStream leaf segments are disguised as `page-N.html`. Those URLs return **HTTP 403** (Cloudflare HTML) when `Referer` or `Origin` is set, and **HTTP 200 MPEG-TS** when those headers are omitted.

Forja always attached CDN self-Referer/Origin from the extractor (issue [036](036-[fixed]-vidsrc-cloudnestra-cdn-host-stale.md)) and Dart `resolvePlaybackHttpHeaders` also **derived** Referer from the stream host when missing — so every segment request was poisoned after a successful playlist probe.

Wyzie `HTTP 403` in the same logs is subtitles-only and unrelated.

### Fix (shipped)

- Rust `resolve_vidsrc_embed_json` / `extract_vidsrc_chain_json`: playback headers = UA only.
- `HeaderManager` vidsrc defaults: no Referer.
- Host `resolvePlaybackHttpHeaders`: for tokenized `/pl/…/.m3u8?token=` URLs, strip Referer/Origin and do not derive them.

### Verify

```bash
cd crates && cargo test -p webstreamr vidsrc::tests --lib
cd apps/forja && flutter test test/player_playback_headers_test.dart
./scripts/resolve-engine.sh -p vidsrc --tmdb=94997 --media=tv --season=1 --episode=1 --native-only
```

## Related

- [036](036-[fixed]-vidsrc-cloudnestra-cdn-host-stale.md) — CDN host derivation (kept; Referer/Origin on playback was wrong for CloudStream)
- [047](047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — vsembed.su + plugin request
- [Stream providers](../../features/sources/stream-providers.md)
