# RFC-051: IPTV multi-protocol portals (Xtream / M3U / Stalker)

**Status:** open  
**Depends on:** [RFC-036](036-[open]-accounts-iptv-profile-settings.md), [RFC-040](040-[open]-iptv-catalog-ops.md) (R40-A12)  
**Area:** `apps/forja/lib/features/iptv/`, `crates/iptv/`, `apps/web/supabase/`

## Status at a glance

| | |
|--|--|
| **Progress** | **5 / 5** components · **11 / 12** acceptance (R51-A12 / R40-A12 after migration apply) |
| **Current slice** | Code shipped — apply `iptv_portals_platform` migration to unlock cloud `platform` |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R51-C01 | `iptv_portals.platform` + upsert/get RPC round-trip | ✅ |
| 2 | R51-C02 | Rust Stalker client (handshake → catalog → create_link) | ✅ |
| 3 | R51-C03 | Rust M3U fetch catalog (URL → groups/streams) | ✅ |
| 4 | R51-C04 | Host: `IptvPortalPlatform`, unified form, controller resolve | ✅ |
| 5 | R51-C05 | Migrate device-local M3U → portals; retire side playlists screen | ✅ |

---

## Acceptance (multi-protocol)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R51-A01 | Add Portal type chips: Xtream · M3U · Stalker; fields switch per type | ✅ |
| 2 | R51-A02 | M3U portal loads Live catalog (group = category); Movies/Series chips hidden | ✅ |
| 3 | R51-A03 | Stalker portal loads Live · Movies · Series via ordered_list | ✅ |
| 4 | R51-A04 | Stalker play/probe uses `create_link` (no static path URLs) | ✅ |
| 5 | R51-A05 | M3U + Stalker portals sync to cloud profile like Xtream | ✅ |
| 6 | R51-A06 | Legacy `M3uStore` playlists migrate into verified M3U portals once | ✅ |
| 7 | R51-A07 | Portals panel playlist-icon side entry removed | ✅ |
| 8 | R51-A08 | CSV / share encode `platform` (default xtream for old rows) | ✅ |
| 9 | R51-A09 | EPG unchanged for Xtream; M3U/Stalker skip Xtream EPG calls | ✅ |
| 10 | R51-A10 | Feature guides + changelog for unified portals | ✅ |
| 11 | R51-A11 | Rust golden + Dart parity for stalker normalize + m3u fetch catalog | ✅ |
| 12 | R51-A12 | R40-A12 marked done when this acceptance ships | ⬜ |

---

## Summary

Forja IPTV today is Xtream-first in the main catalog, with M3U on a device-local side screen and Stalker only in admin scrape. This RFC makes **Xtream / M3U / Stalker** first-class portal types in one catalog browser, cloud-synced, with Rust Pattern B clients for Stalker and M3U fetch.

## Goals

1. One Add Portal flow with platform chips.
2. One browser UX; shelf chips platform-aware (M3U = Live only).
3. Stalker Live + VOD + Series with `create_link` resolve.
4. Cloud sync for all three platforms via `iptv_portals.platform`.

## Out of scope

- Admin Deal/scrape assigning Stalker/M3U into user profiles
- Stalker/M3U EPG parity with Xtream guide
- Per-platform portal slot limits

## Related

- [RFC-040 R40-A12](040-[open]-iptv-catalog-ops.md) — deferred row superseded by this RFC
- [iptv-xtream.md](../features/live/iptv-xtream.md) · [iptv-m3u.md](../features/live/iptv-m3u.md) · [iptv-stalker.md](../features/live/iptv-stalker.md)
