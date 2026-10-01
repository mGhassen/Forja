# 306 — IPTV player Search / Guide missing (vault + catalog gate)

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** IPTV live player chrome · `PortalChannelGuideOpen` · Android TV / desktop  
**Reported:** 2026-09-21

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 6 / 6** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I306-T01 | `PortalChannelGuideOpen.build` uses `PortalsHost.loadVaultVerifiedPortals` + shared `matchPortal` | ✅ |
| 2 | I306-T02 | `HostPlaybackOpen._portalForKey` + channel health probe vault-first (same matcher) | ✅ |
| 3 | I306-T03 | Unit test: pack `url\|username` and `portal.key` match vault list | ✅ |
| 4 | I306-T04 | Sync one-channel `stub` guide at open so Search/Guide paint before full shelf | ✅ |
| 5 | I306-T05 | Shelf-first `_liveCatalog` (hub `PortalCatalogShelfStore`) before network; debug start/ok logs | ✅ |
| 6 | I306-T06 | `didUpdateWidget` applies stub → full guide (not only null → first) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I306-A01 | Android TV: open vault-only Add/Import live channel → chrome shows Search + Guide after guide attaches | ⬜ |
| 2 | I306-A02 | Android TV: Search + Guide visible on first chrome paint (before full shelf) for VIP-sized lineup | ⬜ |

---

## Summary

On Android TV (and desktop), the IPTV live player bottom-right **Search** and **Guide** buttons were missing while Play / Replay showed. Playback still started from the open URL. Repro screenshot: VIP channel, LIVE scrubber, empty bottom-right.

## Root cause

1. **Vault miss (partial):** Guide build used `PortalStore` while Add/Import write the engine vault only.
2. **Catalog gate (primary for empty chrome + ANR):** Search/Guide only paint when `channelGuide != null`. Full live catalog was re-fetched + `jsonDecode`d on the UI isolate under MediaKit, ignoring the hub shelf. Until that finished (or ANR’d), chrome stayed Play/Replay only. Success path logged nothing — so missing `[PortalGuide]` lines did not prove the future never started.

## Fix

- Vault-first portal match (shared `matchPortal`).
- **Stub** one-channel guide at open → Search/Guide immediate.
- **Shelf-first** full guide from `PortalCatalogShelfStore`, network only on miss.
- Apply stub → full via `didUpdateWidget` identity check.

## Related

- [IPTV Xtream](../../features/live/iptv-xtream.md)
- Changelog draft: Search/Guide stub + shelf
