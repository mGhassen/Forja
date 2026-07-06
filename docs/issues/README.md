# Issues

Tracked problems and follow-ups not yet scheduled in a migration phase or RFC.

## Naming

Filename includes status after the number:

| Tag | Meaning |
|-----|---------|
| **`NNN-[open]-…`** | Not done, or in progress |
| **`NNN-[workaround]-…`** | Symptom addressed; root cause still open — see linked root issue |
| **`NNN-[fixed]-…`** | Root cause fixed and verified |

Rename the file when status changes. **Filename tag and `**Status:**` in the issue body must always match** (see [honesty rule](../../.cursor/rules/honesty-and-completion.mdc)).

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
| [001-[workaround]-…](001-[workaround]-webstreamr-blocks-ui.md) | WebStreamr extraction blocks the UI thread | P1 | High | workaround |
| [002-[open]-…](002-[open]-torrent-disk-cache-not-cleaned.md) | Torrent stream cache never purged from disk | P2 | High | open |
| [003-[fixed]-…](003-[fixed]-stremio-platform-playback-model.md) | Match Stremio platform playback model | P2 | Medium | fixed |
| [004-[open]-…](004-[open]-sync-ffi-ui-thread-audit.md) | Sync Rust FFI on UI thread — parent audit | P1 | High | open |
| [005-[workaround]-…](005-[workaround]-stremio-http-blocks-ui.md) | Stremio addon HTTP blocks UI thread | P1 | High | workaround |
| [006-[workaround]-…](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy extractors block UI thread | P1 | High | workaround |
| [007-[workaround]-…](007-[workaround]-torrent-search-blocks-ui.md) | Torrent search/filter blocks UI thread | P1 | High | workaround |
| [008-[fixed]-…](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI must reject sync FFI in app/api | P1 | High | fixed |
| [009-[workaround]-…](009-[workaround]-post-migration-resilience-audit.md) | Post-migration resilience audit (fail/cancel) | P2 | Medium | workaround |
| [010-[fixed]-…](010-[fixed]-webview-js-extractors-main-thread.md) | WebView / JS / WASM extractors main thread | P2 | Medium | fixed |
| [011-[workaround]-…](011-[workaround]-kisskh-hls-sync-ffi.md) | Kisskh decrypt and HLS parse sync FFI | P2 | Medium | workaround |
| [012-[fixed]-…](012-[fixed]-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E (P2-14) | P2 | Medium | fixed |
| [013-[open]-…](013-[open]-site111477-captcha-still-dart.md) | 111477 captcha/CF still in Dart | P3 | Low | open |
| [014-[fixed]-…](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit catalog cursor infinite loop | P1 | High | fixed |
| [015-[open]-…](015-[open]-rust-blocking-http-engine-debt.md) | Rust blocking HTTP / sync resolve engine debt | P2 | Medium | open |

**Workaround vs fixed:** [001](001-[workaround]-webstreamr-blocks-ui.md), [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md) — isolate offload stops UI freeze; **root fix open** in [015](015-[open]-rust-blocking-http-engine-debt.md). [008](008-[fixed]-ci-enforce-no-sync-ffi.md) and [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) are **fixed** (complete).

**Parent:** [004](004-[open]-sync-ffi-ui-thread-audit.md) closes when [015](015-[open]-rust-blocking-http-engine-debt.md) done. Host cancel UX: [009](009-[workaround]-post-migration-resilience-audit.md) workaround shipped.

Add new items as `NNN-[open]-short-slug.md`. Set **Priority**, **Severity**, and **Status**. Rename when status changes: `[open]` → `[workaround]` or `[fixed]`.
