# 009 — Post-migration resilience audit (broken network / cancel / UX)

**Priority:** P2  
**Severity:** Medium  
**Status:** open  
**Area:** `apps/forja`, `packages/api`  
**Reported:** 2026-07-06

## Summary

Wave 1 migration verified **functional parity** (Rust goldens, happy-path smoke). It did **not** systematically test behavior under failure: dead networks, timeouts, empty scrapes, mid-flight cancel. Users hit "app stuck" when backends fail — often UI thread blocking ([004](004-sync-ffi-ui-thread-audit.md)) plus missing cancel paths and infinite retry loops.

## Scope — audit each flow

| Flow | Failure modes to test | Cancel? | Known gaps |
|------|----------------------|---------|------------|
| WebStreamr resolve | all sources timeout | partial | [001](001-webstreamr-blocks-ui.md) fixed |
| IPTV scrape | Reddit OAuth/RSS dead | yes (added) | cursor loop fixed |
| IPTV channel scan | no portals | partial | |
| Stremio addon browse | dead addon | no | [005](005-stremio-http-blocks-ui.md) |
| Torrent search | slow scrapers | no | [007](007-torrent-search-blocks-ui.md) |
| Vidsrc resolve | embed chain fail | no | [006](006-vidsrc-videasy-extractors-blocks-ui.md) |
| M3U fetch | 403/timeout | no | isolate fixed |
| Provider race | one provider hangs | partial | host orchestration |

## Deliverables

1. Checklist per flow: spinner animates, back works, explicit error message, no infinite loop
2. Automated widget/integration tests where feasible (mock slow FFI)
3. Standard pattern: `isCancelled` flag + Stop button for long operations

## Acceptance

- [ ] Audit checklist completed for all rows
- [ ] Each P1 FFI issue closed or has linked cancel/timeout UX fix
- [ ] No operation can loop unbounded without user-visible status + escape hatch
