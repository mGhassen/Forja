# 056 — AutoEmbed: nested player blocked in headless WebView

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/stream` AutoEmbed URL · `autoembed` EmbedExtractProfile · StreamExtractor

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I56-T01 | Canonical embed → `player.autoembed.co/embed/…` (skip outer `autoembed.co` iframe shell) | ✅ |
| 2 | I56-T02 | `autoembed` profile: `forceDirect` + `deferUntilStrongStream` + CloudFabric referer hosts | ✅ |
| 3 | I56-T03 | Block main-frame navigation to `/asb.html` (“Playback blocked”) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I56-A01 | Resolver HostRequired URL is `player.autoembed.co/embed/tv/94997/1-1/` (not outer `autoembed.co/tv/tmdb/…`) | ✅ |
| 2 | I56-A02 | Unit: `EmbedExtractProfiles.resolve('autoembed').forceDirect == true` | ✅ |
| 3 | I56-A03 | App: AutoEmbed HOTD S1E1 sniff detects stream and opens (manual) | ⬜ |

---

## Summary

`autoembed.co` works in a normal browser. Forja’s headless sniff failed.

### Root cause

1. Outer page `autoembed.co/…` only embeds `player.autoembed.co/embed/…` in an iframe.
2. That player runs anti-sandbox JS: if not `window.top`, or if the iframe looks sandboxed, it blanks the document or redirects to **`/asb.html` (“Playback blocked”)**.
3. Forja loaded the outer URL (often under the optional Embed iframe wrapper), so the nested player always died before a stream was sniffed.

### Fix (shipped)

- Template URL → `https://player.autoembed.co/embed/movie/{id}` / `…/embed/tv/{id}/{s}-{e}/`.
- Host profile: load top-level (`forceDirect`), wait for strong HLS (`deferUntilStrongStream`), prefer embed Referer for CloudFabric CDNs.
- Navigation guard cancels `/asb.html` even on the same host.

## Verify

```bash
./scripts/resolve-engine.sh -p autoembed --tmdb=94997 --media=tv --season=1 --episode=1 --json
cd packages/rust && flutter test test/parity/stream_providers_test.dart
cd apps/forja && flutter test test/stream_extractor_url_test.dart
```

## Related

- [048](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) — same class: iframe wrapper → Playback Restricted
- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — embed sniff profiles
- [Stream providers](../../features/sources/stream-providers.md)
