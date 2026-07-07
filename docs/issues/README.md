# Issues

**Rules:** [docs-rfc-issues](../../.cursor/rules/docs-rfc-issues.mdc) · [honesty](../../.cursor/rules/honesty-and-completion.mdc)

Every issue filename includes a status tag matching `**Status:**` in the body.

| Tag | Body status | Meaning |
|-----|-------------|---------|
| `[draft]` | `draft` | Filed, not being worked |
| `[open]` | `open` | Actively fixing |
| `[workaround]` | `workaround` | Symptom fix only |
| `[fixed]` | `fixed` | Root fixed — in `fixed/` |
| `[canceled]` | `canceled` | Won't fix — in `canceled/` (document why) |

```
file     →  NNN-[draft]-slug.md
fixing   →  NNN-[open]-slug.md
symptom  →  NNN-[workaround]-slug.md
fixed    →  fixed/NNN-[fixed]-slug.md
drop     →  canceled/NNN-[canceled]-slug.md
```

| File | Title | P | Sev | Status |
|------|-------|---|-----|--------|
| [001-[fixed]-…](fixed/001-[fixed]-webstreamr-blocks-ui.md) | WebStreamr blocks UI thread | P1 | High | fixed |
| [002-[draft]-…](002-[draft]-torrent-disk-cache-not-cleaned.md) | Torrent cache never purged | P2 | High | draft |
| [003-[fixed]-…](fixed/003-[fixed]-stremio-platform-playback-model.md) | Stremio playback model | P2 | Medium | fixed |
| [004-[fixed]-…](fixed/004-[fixed]-sync-ffi-ui-thread-audit.md) | Sync FFI UI thread audit | P1 | High | fixed |
| [005-[fixed]-…](fixed/005-[fixed]-stremio-http-blocks-ui.md) | Stremio HTTP blocks UI | P1 | High | fixed |
| [006-[fixed]-…](fixed/006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) | Vidsrc/Videasy blocks UI | P1 | High | fixed |
| [007-[fixed]-…](fixed/007-[fixed]-torrent-search-blocks-ui.md) | Torrent search blocks UI | P1 | High | fixed |
| [008-[fixed]-…](fixed/008-[fixed]-ci-enforce-no-sync-ffi.md) | CI reject sync FFI | P1 | High | fixed |
| [009-[fixed]-…](fixed/009-[fixed]-post-migration-resilience-audit.md) | Resilience audit | P2 | Medium | fixed |
| [010-[fixed]-…](fixed/010-[fixed]-webview-js-extractors-main-thread.md) | WebView extractors main thread | P2 | Medium | fixed |
| [011-[fixed]-…](fixed/011-[fixed]-kisskh-hls-sync-ffi.md) | Kisskh/HLS sync FFI | P2 | Medium | fixed |
| [012-[fixed]-…](fixed/012-[fixed]-mobile-magnet-e2e-p2-14.md) | Mobile magnet E2E | P2 | Medium | fixed |
| [013-[fixed]-…](fixed/013-[fixed]-site111477-captcha-still-dart.md) | 111477 Dart by design | P3 | Low | fixed |
| [014-[fixed]-…](fixed/014-[fixed]-iptv-reddit-catalog-cursor-loop.md) | IPTV Reddit cursor loop | P1 | High | fixed |
| [015-[fixed]-…](fixed/015-[fixed]-rust-blocking-http-engine-debt.md) | Rust blocking HTTP debt | P2 | Medium | fixed |
| [016-[fixed]-…](fixed/016-[fixed]-async-job-ffi-hard-cancel.md) | Async job FFI cancel | P2 | Medium | fixed |
| [017-[fixed]-…](fixed/017-[fixed]-webstreamr-stream-choice-button-missing.md) | WebStreamr stream-choice button | P2 | Medium | fixed |
| [018-[draft]-…](018-[draft]-migration-playback-parity-unverified.md) | Playback parity unverified | P1 | High | draft |
| [019-[draft]-…](019-[draft]-webstreamr-enginejobs-e2e-test-gap.md) | WebStreamr E2E test gap | P2 | Medium | draft |
| [020-[draft]-…](020-[draft]-cancel-gen-token-discard-unverified.md) | Cancel gen-token unverified | P2 | Medium | draft |
| [021-[draft]-…](021-[draft]-catalog-vertical-import-smoke-unverified.md) | Catalog import smoke unverified | P3 | Low | draft |
| [022-[draft]-…](022-[draft]-playback-widget-integration-tests.md) | No playback widget tests | P3 | Low | draft |
| [023-[fixed]-…](fixed/023-[fixed]-packages-api-delete-blocked-host-relocation.md) | packages/api delete | P2 | Medium | fixed |

**Migration parity (draft):** [018](018-[draft]-migration-playback-parity-unverified.md) → [019](019-[draft]-webstreamr-enginejobs-e2e-test-gap.md)–[022](022-[draft]-playback-widget-integration-tests.md).

## Related

- [RFC index](../rfc/README.md)
- [Backlog](../backlog/README.md)
