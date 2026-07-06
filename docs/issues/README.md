# Issues

Tracked problems and follow-ups not yet scheduled in a migration phase or RFC.

## Priority / severity

| Label | Meaning |
|-------|---------|
| **P0** | Ship blocker — data loss, crash, security |
| **P1** | User-visible freeze or broken core flow — fix soon |
| **P2** | Important — debt, resilience, device gaps |
| **P3** | Low — tech debt, future platforms |

| Severity | Meaning |
|----------|---------|
| **Critical** | App unusable / data loss |
| **High** | Feels broken (freeze, infinite loop) |
| **Medium** | Degraded UX or unverified path |
| **Low** | Maintenance / future risk |

## Index

| # | Title | P | Sev | Status |
|---|-------|---|-----|--------|
| [001](001-webstreamr-blocks-ui.md) | WebStreamr extraction blocks the UI thread | P1 | High | fixed |
| [002](002-torrent-disk-cache-not-cleaned.md) | Torrent stream cache never purged from disk | P2 | High | open |
| [003](003-stremio-platform-playback-model.md) | Match Stremio platform playback model | P2 | Medium | open |
| [004](004-sync-ffi-ui-thread-audit.md) | Sync Rust FFI on UI thread — parent audit | P1 | High | open |
| [005](005-stremio-http-blocks-ui.md) | Stremio addon HTTP blocks UI thread | P1 | High | open |
| [006](006-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy extractors block UI thread | P1 | High | open |
| [007](007-torrent-search-blocks-ui.md) | Torrent search/filter blocks UI thread | P1 | High | open |
| [008](008-ci-enforce-no-sync-ffi.md) | CI must reject sync FFI in app/api | P1 | High | open |
| [009](009-post-migration-resilience-audit.md) | Post-migration resilience audit (fail/cancel) | P2 | Medium | open |
| [010](010-webview-js-extractors-main-thread.md) | WebView / JS / WASM extractors main thread | P2 | Medium | open |
| [011](011-kisskh-hls-sync-ffi.md) | Kisskh decrypt and HLS parse sync FFI | P2 | Medium | open |
| [012](012-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E not verified (P2-14) | P2 | Medium | open |
| [013](013-site111477-captcha-still-dart.md) | 111477 captcha/CF still in Dart | P3 | Low | open |
| [014](014-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit catalog cursor infinite loop | P1 | High | fixed |

**Parent:** [004](004-sync-ffi-ui-thread-audit.md) owns the FFI inventory. [005](005-stremio-http-blocks-ui.md)–[008](008-ci-enforce-no-sync-ffi.md) are the open P1 children.

Add new items as `NNN-short-slug.md` (next number in sequence). Always set **Priority**, **Severity**, and **Status**.
