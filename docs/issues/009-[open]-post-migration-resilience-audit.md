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
- **Streaming details** (`streaming_details_screen.dart`): Cancel stops WebStreamr, Vidsrc (gen token), headless WebView extractors, Videasy provider loop.
- **IPTV channel scan**: `isCancelled` on portal verify + early exit during parallel portal fetch.
- P1 FFI offload closed in [005](005-[fixed]-stremio-http-blocks-ui.md)–[008](008-[fixed]-ci-enforce-no-sync-ffi.md), [011](011-[fixed]-kisskh-hls-sync-ffi.md).

## Scope — audit each flow

| Flow | Failure modes to test | Cancel? | Known gaps |
|------|----------------------|---------|------------|
| WebStreamr resolve | all sources timeout | partial | [001](001-[fixed]-webstreamr-blocks-ui.md) fixed |
| IPTV scrape | Reddit OAuth/RSS dead | yes (added) | cursor loop fixed |
| IPTV channel scan | no portals | partial | |
| Stremio addon browse | dead addon | yes (details) | [005](005-[fixed]-stremio-http-blocks-ui.md) fixed |
| Torrent search | slow scrapers | yes (details) | [007](007-[fixed]-torrent-search-blocks-ui.md) fixed |
| Vidsrc resolve | embed chain fail | yes (streaming cancel) | [006](006-[fixed]-vidsrc-videasy-extractors-blocks-ui.md) fixed |
| M3U fetch | 403/timeout | no | isolate fixed |
| Provider race | one provider hangs | yes (streaming cancel) | vidsrc/videasy/webview cancel wired |

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
- [x] Streaming provider race: cancel invalidates vidsrc / videasy / webview / webstreamr
- [ ] No operation can loop unbounded without user-visible status + escape hatch (remaining: nuvio scraper, player fallback race)
