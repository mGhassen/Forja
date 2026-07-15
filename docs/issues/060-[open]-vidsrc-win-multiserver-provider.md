# 060 — VidSrc.win multi-server provider

**Status:** open
**Priority:** P1
**Severity:** High
**Area:** `crates/stream` provider templates · Resolver Engine host plugin · `vidsrcwin` EmbedExtractProfile

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** fix tasks · **3 / 4** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I60-T01 | Add `vidsrcwin` movie/TV templates and a standalone Resolver Engine `HostRequired` plugin | ✅ |
| 2 | I60-T02 | Bypass the CAPTCHA-gated outer page; direct-load its MoviePire player, wait for HLS/DASH, and rotate Alpha/Blaze | ✅ |
| 3 | I60-T03 | Register `vidsrcwin` in provider settings/order/display while preserving the existing `vidsrc` ID and relabeling it `VSEmbed` | ✅ |
| 4 | I60-T04 | Add Rust/Dart parity tests, provider documentation, and release notes | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I60-A01 | Movie URL is `https://video.moviepire.co/embed/movie/550`; TV URL is `https://video.moviepire.co/embed/tv/94997/1/1` | ✅ |
| 2 | I60-A02 | Existing `vidsrc` appears as `VSEmbed`; new `vidsrcwin` appears as `VidSrc` without invalidating saved `vidsrc` settings | ✅ |
| 3 | I60-A03 | Unit tests verify direct load, strong-stream deferral, and Alpha/Blaze server rotation policy | ✅ |
| 4 | I60-A04 | App smoke: VidSrc HOTD S1E1 rotates past a stalled server, detects a playable stream, and opens | ⬜ |

---

## Summary

The public [VidSrc](https://vidsrc.win/watch/94997?s=1&e=1) watch page exposes server navigation, but Forja's existing `vidsrc` provider bypasses that site and resolves one `vsembed.su` CDN chain in Rust.

This issue adds the public service as a separate `vidsrcwin` provider. Live inspection found that the outer watch page is CAPTCHA-gated and embeds its actual player from `video.moviepire.co`, so Forja targets that player directly. The existing `vidsrc` internal ID remains unchanged for settings compatibility and is relabeled **VSEmbed** so the two providers are distinct in Settings and the player.

## Implementation

- Resolver Engine produces a `HostRequired` request for `video.moviepire.co/embed/movie/{tmdb}` or `/embed/tv/{tmdb}/{season}/{episode}`.
- The host opens that player directly, waits for a playlist, keeps cookies, and rotates its Alpha (HLS) / Blaze (MP4) server entries.
- Browser verification confirmed both Fight Club (`movie/550`) and HOTD S1E1 (`tv/94997/1/1`) load without CAPTCHA and can switch Alpha/Blaze; the outer `vidsrc.win/watch` page itself requires CAPTCHA.
- New installs place VidSrc immediately after VSEmbed. Existing saved orders retain `vidsrc` and append the newly available provider through the normal settings migration.
- Rust workspace, provider parity, display, source-order, and host-profile tests pass. Native assets were rebuilt.

## Manual verification remaining

`I60-A04` remains open until a desktop/mobile app smoke confirms the live site's current server controls still produce a playable stream.

## Verify

```bash
cd crates && cargo test -p stream && cargo test -p resolver-engine
cd packages/rust && flutter test test/parity/stream_providers_test.dart test/stream_provider_display_test.dart
cd apps/forja && flutter test test/stream_extractor_url_test.dart
```

## Related

- [RFC-004](../rfc/004-[partial]-provider-registry.md) — provider registry expansion (`R04-A11`)
- [047](fixed/047-[fixed]-vidsrc-vsembed-su-and-broken-plugin.md) — existing `vsembed.su` native provider
- [051](051-[open]-embed-multiserver-sniff-proxy-cookies.md) — generic host multi-server extraction
- [057](fixed/057-[fixed]-2embed-stale-cc-url-multiserver.md) — template multi-server precedent
- [Stream providers](../features/sources/stream-providers.md)
