# Issues

Tracked problems and follow-ups not yet scheduled in a migration phase or RFC.

## Naming

Filename includes status after the number: **`NNN-[fixed]-short-slug.md`** or **`NNN-[open]-short-slug.md`**.  
Use **`[open]`** for anything not fully closed (including in-progress). Rename the file when status changes.

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

| File | Title | P | Sev | Status |
|------|-------|---|-----|--------|
| [001-[fixed]-…](001-[fixed]-webstreamr-blocks-ui.md) | WebStreamr extraction blocks the UI thread | P1 | High | fixed |
| [002-[open]-…](002-[open]-torrent-disk-cache-not-cleaned.md) | Torrent stream cache never purged from disk | P2 | High | open |
| [003-[open]-…](003-[open]-stremio-platform-playback-model.md) | Match Stremio platform playback model | P2 | Medium | open |
| [004-[open]-…](004-[open]-sync-ffi-ui-thread-audit.md) | Sync Rust FFI on UI thread — parent audit | P1 | High | open |
| [005-[fixed]-…](005-[fixed]-stremio-http-blocks-ui.md) | Stremio addon HTTP blocks UI thread | P1 | High | fixed |
| [006-[fixed]-…](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy extractors block UI thread | P1 | High | fixed |
| [007-[fixed]-…](007-[fixed]-torrent-search-blocks-ui.md) | Torrent search/filter blocks UI thread | P1 | High | fixed |
| [008-[fixed]-…](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI must reject sync FFI in app/api | P1 | High | fixed |
| [009-[open]-…](009-[open]-post-migration-resilience-audit.md) | Post-migration resilience audit (fail/cancel) | P2 | Medium | open |
| [010-[open]-…](010-[open]-webview-js-extractors-main-thread.md) | WebView / JS / WASM extractors main thread | P2 | Medium | open |
| [011-[fixed]-…](011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh decrypt and HLS parse sync FFI | P2 | Medium | fixed |
| [012-[open]-…](012-[open]-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E not verified (P2-14) | P2 | Medium | open |
| [013-[open]-…](013-[open]-site111477-captcha-still-dart.md) | 111477 captcha/CF still in Dart | P3 | Low | open |
| [014-[fixed]-…](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit catalog cursor infinite loop | P1 | High | fixed |

**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md) owns the FFI inventory. P1 children [005](005-[fixed]-stremio-http-blocks-ui.md)–[008](008-[fixed]-ci-enforce-no-sync-ffi.md) are fixed; parent closes when [009](009-[open]-post-migration-resilience-audit.md) is done.

Add new items as `NNN-[open]-short-slug.md` (next number in sequence). Always set **Priority**, **Severity**, and **Status** (`fixed` or `open`). When closing, rename to `NNN-[fixed]-…`.
