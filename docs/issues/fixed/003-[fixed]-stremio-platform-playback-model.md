# 003 — Match Stremio platform playback model

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `apps/forja`, `packages/api`, `crates/torrent`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06

## Summary

Forja now follows Stremio's **platform-constrained playback model** via a shared `PlaybackProfile` and `resolveStremioStream()`. Desktop/Android/iOS keep the local torrent engine; web (`kIsWeb`) uses the `constrained` profile (no engine, debrid-only for `infoHash`).

## Shipped

| Piece | Location |
|-------|----------|
| `PlaybackProfile` + `PlatformPlayback.capabilities` | `packages/api/lib/playback/playback_profile.dart` |
| `resolveStremioStream()`, `filterStremioStreamsForProfile()` | `packages/api/lib/playback/stremio_stream_resolver.dart` |
| Details play path | `apps/forja/lib/features/home/details_screen.dart` |
| Streaming details Stremio path | `apps/forja/lib/features/home/streaming_details_screen.dart` |
| Skip torrent engine on constrained | `apps/forja/lib/app/bootstrap.dart`, `torrent_stream_service.dart` |
| Hide torrent UI (magnet nav, Jackett/Prowlarr settings, torrent source tab) | `main_screen.dart`, `settings_screen.dart`, `details_screen.dart` |
| Docs | `docs/features/sources/stremio-addons.md` |

### Profiles

| Profile | When | `localTorrentEngine` | `stremioInfoHash` | `builtinTorrentSearch` |
|---------|------|----------------------|-------------------|------------------------|
| `desktop` | Native (Android, iOS, Win, Mac, Linux) | yes | `localEngine` | yes |
| `constrained` | `kIsWeb`, unknown/fuchsia | no | `debridOnly` | no |

### Direct streaming mode

Unchanged on desktop: direct streaming mode remains WebStreamr-first (`streaming_details_screen.dart` default source `'forja'`). Stremio hash playback on desktop details screen is unchanged.

## Acceptance

- [x] `PlaybackProfile` defined; `desktop` and `constrained` profiles implemented
- [x] Single `resolveStremioStream()` used by `details_screen` and `streaming_details_screen`
- [x] On `constrained`: `infoHash` streams without debrid show clear message, not torrent spinner
- [x] On `constrained`: torrent engine does not start; torrent UI hidden
- [x] On `desktop`/`android`: behavior unchanged (url direct, infoHash → librqbit or debrid)
- [x] RFC-010 web build uses `constrained` profile without duplicating guards
- [x] Docs: `docs/features/sources/stremio-addons.md` notes platform limits for hash-based addons

## Future (out of scope)

- Tizen / webOS targets — reuse `PlaybackProfile.constrained`; extend `_detect()` when those platforms land.
- Optional: treat direct streaming mode as constrained for torrent UI on desktop (product decision deferred).

## Related

- [RFC-010](../rfc/010-[draft]-web-client.md)
- [Stremio addons](../features/sources/stremio-addons.md)
- [002](002-[draft]-torrent-disk-cache-not-cleaned.md) — torrent lifecycle (desktop profile only)
