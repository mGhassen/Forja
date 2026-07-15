# 057 — 2Embed: stale 2embed.cc URL / multi-server sniff

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `crates/stream` 2embed URLs · `2embed` EmbedExtractProfile

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3/3** fix · **2/3** acceptance (app smoke ⬜) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I57-T01 | Migrate template URLs from `www.2embed.cc` → `2embed.stream/embed/…` (docs [2embed.online](https://www.2embed.online/)) | ✅ |
| 2 | I57-T02 | `2embed` profile: `forceDirect` + `deferUntilStrongStream` + rotate Server chips | ✅ |
| 3 | I57-T03 | Allowlist `2embed.online` / `2embed.stream` in stream extractor view host checks | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I57-A01 | Resolver HostRequired URL is `https://2embed.stream/embed/tv/94997/1/1` | ✅ |
| 2 | I57-A02 | Unit: `EmbedExtractProfiles.resolve('2embed').forceDirect` + `rotateServerChips` | ✅ |
| 3 | I57-A03 | App: 2Embed HOTD S1E1 sniff detects stream and opens (manual) | ⬜ |

---

## Summary

[2embed.online](https://www.2embed.online/) works in a browser. Forja failed.

### Root cause

1. Forja still used legacy **`www.2embed.cc`** paths (`/embed/{id}`, `/embedtv/{id}&s=&e=`).
2. That host is **iframe-oriented**: top-level loads redirect to `2embed.skin`, so headless sniff never reaches a playable player.
3. Documented API is `www.2embed.online/embed/movie|tv/…`, which **301s to `2embed.stream`**, with multiple internal servers.

### Fix (shipped)

- Canonical embed → `https://2embed.stream/embed/movie/{id}` / `…/embed/tv/{id}/{season}/{episode}`.
- Host profile: top-level load, wait for strong HLS, rotate generic Server chips when stuck.
- Host allowlist updated for `.online` / `.stream`.

## Verify

```bash
./scripts/resolve-engine.sh -p 2embed --tmdb=94997 --media=tv --season=1 --episode=1 --json
cd crates && cargo test -p stream twoembed_urls --lib
cd packages/rust && flutter test test/parity/stream_providers_test.dart --name 2embed
cd apps/forja && flutter test test/stream_extractor_url_test.dart
```

## Related

- [056](056-[fixed]-autoembed-player-sandbox-playback-blocked.md) — similar host/URL migration
- [048](048-[open]-vidsrc-sbs-iframe-playback-restricted.md) — forceDirect for iframe-hostile players
- [Stream providers](../../features/sources/stream-providers.md)
