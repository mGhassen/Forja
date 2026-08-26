# RFC-051: IPTV multi-protocol portals (Xtream / M3U / Stalker)

**Status:** open  
**Depends on:** [RFC-036](036-[open]-accounts-iptv-profile-settings.md), [RFC-040](040-[open]-iptv-catalog-ops.md) (R40-A12)  
**Area:** `apps/forja/lib/features/iptv/`, `crates/iptv/`, `apps/web/supabase/`

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** components · **18 / 19** acceptance (multi-protocol) · **7 / 7** Lume parity · **3 / 3** Stalker EPG |
| **Current slice** | Stalker EPG wired — apply `iptv_portals_platform` migration still unlocks cloud `platform` (R51-A12) |

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
| 6 | R51-C06 | Host: Generate MAC (Stalker) + local-file picker (M3U) in Add Portal | ✅ |
| 7 | R51-C07 | Rust Stalker EPG (`get_short_epg` / `get_epg_info`) + host wiring | ✅ |

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

## Acceptance (Lume parity slice — Stalker core + UX, M3U improvements)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 13 | R51-A13 | Stalker handshake tries candidate endpoints (`portal.php` / `server/load.php` / `stalker_portal/server/load.php`, ordered by pasted URL hint) and pins the winner | ✅ |
| 14 | R51-A14 | Stalker session (token + endpoint) cached per `portal_origin|mac` across login/catalog/streams/create_link calls in-process; 401/403 clears cache and re-handshakes once | ✅ |
| 15 | R51-A15 | Stalker `create_link` forwards embedded `cmd` query params (Xtream-UI-style Stalker emulations) and rejects links with an empty `stream=` | ✅ |
| 16 | R51-A16 | Stalker VOD/Series ordered-list walk fetches pages ~6 at a time once `total_items` is known, instead of serially | ✅ |
| 17 | R51-A17 | M3U parser reads the `#EXTM3U` header's `url-tvg`/`x-tvg-url` EPG URL and the per-entry `type=` attribute (loose VOD classification); Enigma2/Gigablue bouquet links get a distinct error instead of "no channels" | ✅ |
| 18 | R51-A18 | M3U fetch supports local `file://` playlists and streams remote downloads to a temp file before parsing (no full-body double-buffering) | ✅ |
| 19 | R51-A19 | Add Portal → Stalker has a **Generate MAC** button (MAG OUI); M3U has a **choose local file** picker that fills the URL field with `file://` | ✅ |

---

## Acceptance (Stalker EPG)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 20 | R51-A20 | Live catalog stores Stalker numeric `ch_id` as `epg_channel_id` (create_link `cmd` stays `stream_id`) | ✅ |
| 21 | R51-A21 | Stalker short EPG via MAG `get_short_epg` → `get_epg_info` fallback; cards / long-press / in-player guide | ✅ |
| 22 | R51-A22 | Stalker Live EPG guide grid uses the same listings (session-cached); M3U still skips EPG | ✅ |

---

## Summary

Forja IPTV today is Xtream-first in the main catalog, with M3U on a device-local side screen and Stalker only in admin scrape. This RFC makes **Xtream / M3U / Stalker** first-class portal types in one catalog browser, cloud-synced, with Rust Pattern B clients for Stalker and M3U fetch.

## Goals

1. One Add Portal flow with platform chips.
2. One browser UX; shelf chips platform-aware (M3U = Live only).
3. Stalker Live + VOD + Series with `create_link` resolve.
4. Cloud sync for all three platforms via `iptv_portals.platform`.
5. Stalker programme guide parity with Xtream EPG surfaces (cards, sheet, in-player, Live guide).

## Out of scope

- Admin Deal/scrape assigning Stalker/M3U into user profiles
- M3U XMLTV EPG parity with Xtream / Stalker guide
- Per-platform portal slot limits

## Related

- [RFC-040 R40-A12](040-[open]-iptv-catalog-ops.md) — deferred row superseded by this RFC
- [iptv-xtream.md](../features/live/iptv-xtream.md) · [iptv-m3u.md](../features/live/iptv-m3u.md) · [iptv-stalker.md](../features/live/iptv-stalker.md)
