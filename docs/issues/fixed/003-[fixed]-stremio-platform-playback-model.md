# 003 — Match Stremio platform playback model

**Priority:** P2  
**Severity:** Medium  
**Status:** fixed  
**Area:** `apps/forja`, `packages/api`, `crates/torrent`  
**Reported:** 2026-07-06  
**Fixed:** 2026-07-06
## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 7 / 7** |
| **Backlog** | [0.2.0](../backlog/done/0.2.0-[done].md) |


**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---


## Summary

Forja now follows Stremio's **platform-constrained playback model** via a shared `PlaybackProfile` and `resolveStremioStream()`. Desktop/Android/iOS keep the local torrent engine; web (`kIsWeb`) uses the `constrained` profile (no engine, debrid-only for `infoHash`).

## Shipped

| Piece | Location |
|-------|----------|
| `PlaybackProfile` + `PlatformPlayback.capabilities` | `packages/api/lib/playback/platform/playback_profile.dart` |
| `resolveStremioStream()`, `filterStremioStreamsForProfile()` | `packages/api/lib/playback/stremio/stremio_stream_resolver.dart` |
| Details play path | `apps/forja/lib/features/home/details_screen.dart` |
| Streaming details Stremio path | `apps/forja/lib/features/home/streaming_details_screen.dart` |
| Skip torrent engine on constrained | `apps/forja/lib/app/bootstrap.dart`, `torrent_stream_service.dart` |
| Hide torrent UI (magnet nav, Jackett/Prowlarr settings, torrent source tab) | `main_screen.dart`, `settings_screen.dart`, `details_screen.dart` |
| Docs | `docs/features/archive/sources/stremio-addons.md` |

### Profiles

| Profile | When | `localTorrentEngine` | `stremioInfoHash` | `builtinTorrentSearch` |
|---------|------|----------------------|-------------------|------------------------|
| `desktop` | Native (Android, iOS, Win, Mac, Linux) | yes | `localEngine` | yes |
| `constrained` | `kIsWeb`, unknown/fuchsia | no | `debridOnly` | no |

### Direct streaming mode

Unchanged on desktop: direct streaming mode remains WebStreamr-first (`streaming_details_screen.dart` default source `'forja'`). Stremio hash playback on desktop details screen is unchanged.


## Future (out of scope)

- Tizen / webOS targets — reuse `PlaybackProfile.constrained`; extend `_detect()` when those platforms land.
- Optional: treat direct streaming mode as constrained for torrent UI on desktop (product decision deferred).

## Related

- [RFC-010](../rfc/010-[draft]-web-client.md)
- [Stremio addons](../features/archive/sources/stremio-addons.md)
- [002](002-[fixed]-torrent-disk-cache-not-cleaned.md) — torrent lifecycle (desktop profile only)
