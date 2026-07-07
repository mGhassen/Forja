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
| [001-[fixed]-…](001-[fixed]-webstreamr-blocks-ui.md) | WebStreamr extraction blocks the UI thread | P1 | High | fixed |
| [002-[open]-…](002-[open]-torrent-disk-cache-not-cleaned.md) | Torrent stream cache never purged from disk | P2 | High | open |
| [003-[fixed]-…](003-[fixed]-stremio-platform-playback-model.md) | Match Stremio platform playback model | P2 | Medium | fixed |
| [004-[fixed]-…](004-[fixed]-sync-ffi-ui-thread-audit.md) | Sync Rust FFI on UI thread — parent audit | P1 | High | fixed |
| [005-[fixed]-…](005-[fixed]-stremio-http-blocks-ui.md) | Stremio addon HTTP blocks UI thread | P1 | High | fixed |
| [006-[fixed]-…](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc / Videasy extractors block UI thread | P1 | High | fixed |
| [007-[fixed]-…](007-[fixed]-torrent-search-blocks-ui.md) | Torrent search/filter blocks UI thread | P1 | High | fixed |
| [008-[fixed]-…](008-[fixed]-ci-enforce-no-sync-ffi.md) | CI must reject sync FFI in app/api | P1 | High | fixed |
| [009-[fixed]-…](009-[fixed]-post-migration-resilience-audit.md) | Post-migration resilience audit (fail/cancel) | P2 | Medium | fixed |
| [010-[fixed]-…](010-[fixed]-webview-js-extractors-main-thread.md) | WebView / JS / WASM extractors main thread | P2 | Medium | fixed |
| [011-[fixed]-…](011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh decrypt and HLS parse sync FFI | P2 | Medium | fixed |
| [012-[fixed]-…](012-[fixed]-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E (P2-14) | P2 | Medium | fixed |
| [013-[fixed]-…](013-[fixed]-site111477-captcha-still-dart.md) | 111477 index scrape / CF retry — Dart by design | P3 | Low | fixed |
| [014-[fixed]-…](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit catalog cursor infinite loop | P1 | High | fixed |
| [015-[fixed]-…](015-[fixed]-rust-blocking-http-engine-debt.md) | Rust blocking HTTP / sync resolve engine debt | P2 | Medium | fixed |
| [016-[fixed]-…](016-[fixed]-async-job-ffi-hard-cancel.md) | Async job FFI + hard HTTP cancel | P2 | Medium | fixed |
| [017-[fixed]-…](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) | WebStreamr stream-choice button missing in player | P2 | Medium | fixed |
| [018-[open]-…](018-[open]-migration-playback-parity-unverified.md) | Wave 1 playback parity vs main unverified | P1 | High | open |
| [019-[open]-…](019-[open]-webstreamr-enginejobs-e2e-test-gap.md) | WebStreamr live E2E bypasses EngineJobs app path | P2 | Medium | open |
| [020-[open]-…](020-[open]-cancel-gen-token-discard-unverified.md) | Gen-token cancel may discard valid results (unverified) | P2 | Medium | open |
| [021-[open]-…](021-[open]-catalog-vertical-import-smoke-unverified.md) | Catalog vertical import migration smoke unverified | P3 | Low | open |
| [022-[open]-…](022-[open]-playback-widget-integration-tests.md) | No widget/integration tests for playback cancel | P3 | Low | open |

**Migration parity (open):** [018](018-[open]-migration-playback-parity-unverified.md) parent → [019](019-[open]-webstreamr-enginejobs-e2e-test-gap.md)–[022](022-[open]-playback-widget-integration-tests.md).

**Sync FFI stack:** [001](001-[fixed]-webstreamr-blocks-ui.md)–[007](007-[fixed]-torrent-search-blocks-ui.md), [011](011-[fixed]-kisskh-hls-sync-ffi.md), [015](015-[fixed]-rust-blocking-http-engine-debt.md), [016](016-[fixed]-async-job-ffi-hard-cancel.md) — **fixed**. Parent [004](004-[fixed]-sync-ffi-ui-thread-audit.md) **fixed**.

Add new items as `NNN-[open]-short-slug.md`. Set **Priority**, **Severity**, and **Status**. Rename when status changes: `[open]` → `[workaround]` or `[fixed]`.
