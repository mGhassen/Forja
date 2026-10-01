# 329 — Host stream guards held pack mirror chip inventory

**Status:** fixed  
**Priority:** P0  
**Severity:** High  
**Area:** `apps/forja/lib/shared/playback/probe/playback_stream_guards.dart`

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **2 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I329-T01 | Delete Videasy / VidNest / VidSrc.win chip-name lists + pack-id branches in `hasForeignProviderTitle` | ✅ |
| 2 | I329-T02 | Rename CDN helpers off pack brands (`preferHlsMasterPlaylistUrl`, `isPeakstormCdnStreamUrl`, `isDmcdnHlsUrl`) | ✅ |
| 3 | I329-T03 | Rewrite ownership tests without pack chip contracts | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I329-A01 | `playback_stream_guards.dart` has no Yoru/Gama/Alpha chip lists or `videasy`/`vidnest` title branches | ✅ |
| 2 | I329-A02 | `provider_source_ownership_test` + peakstorm seek tests pass | ✅ |

---

## Summary

`playback_stream_guards.dart` hardcoded pack mirror labels (Yoru…, Gama…, Alpha/Blaze) and branched on pack ids to detect cache poison. That is pack inventory in the host — [pack-product host](../../.cursor/rules/forja-pack-product-host.mdc) violation.

### Fix

- Ownership = `providerId` (+ generic `StreamProviderDisplay.playerLabel` for restamped display names only)
- CDN seek/master helpers named by host capability, not pack brand

### Still open (not this slice)

- `StreamProviderDisplay._labels` still inventories built-in provider ids in `packages/rust`
- `resolvePlaybackHttpHeaders` still branches on pack ids (`videasy`, `vidnest`, …) for Referer policy

### Related

- [328](328-[fixed]-vidnest-stale-server-backends-wrong-title.md) — VidNest pack backends  
- [172](../172-[open]-vsembed-shows-videasy-streams.md) — was relying on chip-title detection  
- [RFC-109](../../rfc/109-[open]-forja-pack-product-host.md)
