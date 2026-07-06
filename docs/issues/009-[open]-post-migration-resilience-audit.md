# 009 — Post-migration resilience audit (broken network / cancel / UX)

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `apps/forja`, `packages/api`  
**Reported:** 2026-07-06

## Summary

Wave 1 migration verified **functional parity** (Rust goldens, happy-path smoke). It did **not** systematically test behavior under failure: dead networks, timeouts, empty scrapes, mid-flight cancel. Users hit "app stuck" when backends fail — often UI thread blocking ([004](004-[open]-sync-ffi-ui-thread-audit.md)) plus missing cancel paths and infinite retry loops.

## Progress (2026-07-06)

- **Details screen** (`details_screen.dart`): generation-token cancel for torrent search (Forja/Jackett/Prowlarr), Stremio fetch (all addons, single addon, custom ID), Nuvio sub cancel; **Cancel** button in results header while fetching.
- **Streaming details** (`streaming_details_screen.dart`): Cancel stops WebStreamr, Vidsrc (gen token), Nuvio, headless WebView extractors, Videasy provider loop.
- **Details Nuvio tab**: Cancel calls `NuvioService.cancelPending()`.
- **Player fallback** (mobile + desktop): `_fallbackGen` aborts auto-fallback chain on dispose; cancels WebStreamr/Vidsrc/Nuvio in-flight resolves.
- **IPTV channel scan**: `isCancelled` on portal verify + early exit during parallel portal fetch.
- **IPTV scrape**: Stop button + cancel gen (issue [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md)).
- P1 FFI workarounds shipped: [001](001-[workaround]-webstreamr-blocks-ui.md), [005](005-[workaround]-stremio-http-blocks-ui.md)–[007](007-[workaround]-torrent-search-blocks-ui.md), [011](011-[workaround]-kisskh-hls-sync-ffi.md); CI [008](008-[fixed]-ci-enforce-no-sync-ffi.md) fixed.

## Scope — audit each flow

| Flow | Failure modes to test | Cancel? | Known gaps |
|------|----------------------|---------|------------|
| WebStreamr resolve | all sources timeout | partial | [001](001-[workaround]-webstreamr-blocks-ui.md) workaround; Rust still runs on cancel |
| IPTV scrape | Reddit OAuth/RSS dead | yes (added) | [014](014-[fixed]-iptv-reddit-catalog-cursor-loop.md) fixed |
| IPTV channel scan | no portals | partial | |
| Stremio addon browse | dead addon | yes (details) | [005](005-[workaround]-stremio-http-blocks-ui.md) workaround |
| Torrent search | slow scrapers | yes (details) | [007](007-[workaround]-torrent-search-blocks-ui.md) workaround |
| Vidsrc resolve | embed chain fail | yes (streaming cancel) | [006](006-[workaround]-vidsrc-videasy-extractors-blocks-ui.md) workaround |
| M3U fetch | 403/timeout | no | [011](011-[workaround]-kisskh-hls-sync-ffi.md) workaround |
| Provider race | one provider hangs | yes | streaming + player dispose abort |

## Deliverables

1. Checklist per flow: spinner animates, back works, explicit error message, no infinite loop
2. Automated widget/integration tests where feasible (mock slow FFI)
3. Standard pattern: `isCancelled` flag + Stop button for long operations

## Acceptance

- [x] Details tab: cancel + gen-token for torrent / Stremio / Nuvio fetches
- [ ] Audit checklist completed for all rows
- [x] Each P1 FFI issue closed or has linked cancel/timeout UX fix
- [x] IPTV scrape has Stop + bounded empty-page exit
- [x] IPTV channel scan: Stop + cancel through verify + portal fetch
- [x] Streaming provider race: cancel invalidates vidsrc / videasy / webview / webstreamr / nuvio
- [x] Player auto-fallback aborts on exit (no post-pop provider resolve)
- [ ] No operation can loop unbounded without user-visible status + escape hatch (remaining: manual provider switch in player, widget tests)
