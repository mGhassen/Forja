# RFC-036: Accounts hub, global IPTV, profile settings

**Status:** open  
**Depends on:** RFC-006, RFC-034  
**Area:** `apps/web/supabase/`, `apps/web/src/`, `apps/forja/lib/shared/sync/`

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 8** components · **14 / 24** acceptance (account `features` + IPTV scrape flag; web navigation settings; no default profile on signup; M3U out of profile_settings) |
| **Current slice** | Account feature flags (`iptvScrape`) shipped — admin UI for toggling still open; M3U device-local only |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R36-C01 | Supabase: `accounts`, `iptv_portals`, `profile_settings`; drop releases/announcements/`user_settings` | ⬜ |
| 2 | R36-C02 | Web self-serve settings on single profile payload + IPTV portal RPC | ⬜ |
| 3 | R36-C03 | Web admin UI (`/admin`) gated by `accounts.is_admin` | ⬜ |
| 4 | R36-C04 | Flutter `SyncService` / `SyncDomainBridge` single-payload pull/push | ⬜ |
| 5 | R36-C05 | Profile-switch splash (distinct from boot splash) | ✅ |
| 6 | R36-C06 | GitHub-only updater; remove announcements consumer | ✅ |
| 7 | R36-C07 | `user_iptv_portals` assignment table (`portal_name`, favorite); settings iptv = M3U only | 🔄 |
| 8 | R36-C08 | `accounts.features` lean JSON; Flutter pull + IPTV scrape gate | ✅ |

---

## Acceptance (schema + sync)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R36-A01 | `accounts` 1:1 with `auth.users`; profiles/settings FK `account_id` | ⬜ |
| 2 | R36-A02 | Global `iptv_portals` unique by url+username; no active connections; audit columns | ⬜ |
| 3 | R36-A03 | One `profile_settings` row per profile with lean JSON payload (playback, connectedServices, navigation, iptv — no films) | 🔄 |
| 4 | R36-A04 | Per-profile IPTV label in payload; portal credentials only on global row | ⬜ |
| 5 | R36-A05 | `releases` / `release_assets` / `announcements` / `user_settings` dropped | ✅ |
| 6 | R36-A06 | RLS: own rows for users; admin elevated via `is_admin` | ⬜ |
| 7 | R36-A15 | Lean payload: no M3U `channels[]`, omit default provider orders, omit false/empty flags | ✅ |
| 8 | R36-A16 | My List / films not stored in cloud (device-local only) | ✅ |
| 9 | R36-A17 | `user_iptv_portals.portal_name` is the only cloud display name; no `provider_name` on `iptv_portals` | 🔄 |
| 10 | R36-A18 | `profile_settings.playback` stores full prefs including `play_source_*` modes | 🔄 |
| 11 | R36-A19 | `profile_settings.navigation` stores visibleIds + defaultTab | ✅ |
| 12 | R36-A20 | `iptv_portals.password` encrypted at rest (pgcrypto); decrypted only via authorized RPC | ✅ |
| 13 | R36-A21 | `accounts.features` jsonb default `{}`; only enabled keys stored (e.g. `iptvScrape`) | ✅ |

---

## Acceptance (web + Flutter)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 14 | R36-A07 | Web settings pages read/write new payload paths (incl. navigation) | ✅ |
| 15 | R36-A08 | Admin: accounts list, profile settings, global IPTV portals | ⬜ |
| 16 | R36-A09 | Flutter pull/push lean `profile_settings` (navigation yes; films no) | 🔄 |
| 17 | R36-A10 | Profile switch shows dedicated splash until merge completes or fails | ✅ |
| 18 | R36-A11 | App updater no longer reads Supabase releases tables | ✅ |
| 19 | R36-A12 | Announcement banner/service removed or no-ops | ✅ |
| 20 | R36-A13 | Feature docs + changelog updated | ✅ |
| 21 | R36-A14 | Existing multi-domain settings migrate into `profile_settings` without loss | ⬜ |
| 22 | R36-A22 | IPTV Scrape / Find Portals hidden and blocked unless `accounts.features.iptvScrape` | ✅ |
| 23 | R36-A23 | Signup creates `accounts` only — no auto `Profile 1`; user creates first profile; `profile_settings` defaults on profile insert | ✅ |
| 24 | R36-A24 | `profile_settings.payload` has no `iptv` key; M3U playlists are device-local only (portals remain in `iptv_portals` / `user_iptv_portals`) | ✅ |

---

## Summary

Replace multi-domain `user_settings` and Auth-only identity with an `accounts` hub, deduplicated global IPTV portals, and one JSON settings row per profile. Web portal gains admin tools; Flutter syncs the new shape and shows a profile-switch splash.

## Goals

1. Relational `accounts` for all FKs and admin listing.
2. Share Xtream portal rows across users who use the same credentials; keep labels per profile.
3. Single lean settings blob per profile for web + Flutter (no M3U channels, no My List, omit defaults).
4. Operator admin UI without a separate staff auth system (`is_admin` flag).
5. Clear UX when switching profiles (dedicated splash).

## Lean payload (storage)

On write, clients call compact helpers:

- No `films` / My List
- M3U under `iptv`: `{ id, name, sourceUrl, addedAt, updatedAt }` only (no `channels[]`; file M3U stays local)
- Provider order arrays omitted when equal to built-in defaults
- **Provider order is not synced** — device-local in the app only (not on web remote settings)
- **Portal assignments are not in settings JSON** — see `user_iptv_portals`
- **Playback** is stored in full (including `play_source_torrent_enabled` / `stremio` / `webstreaming`)
- **Navigation** (`visibleIds`, `defaultTab`) is stored when set

## Account features

`accounts.features` is a lean JSON object on the account row (not per-profile):

- Default `{}` — all features off (including guests / signed-out)
- Only store enabled keys — e.g. `{ "iptvScrape": true }`
- Never store `"iptvScrape": false`
- First flag: **`iptvScrape`** gates Reddit / Find Portals scrape in the app
- Activation this slice: SQL / seed / service-role; admin UI later (R36-A08)

## Correction (M3U out of settings)

`profile_settings.payload` must **not** contain an `iptv` key. M3U URL/file playlists are device-local only. Portal credentials and assignments stay on `iptv_portals` + `user_iptv_portals`. Migration `20260718120000_strip_iptv_from_profile_settings.sql` strips legacy `iptv` blobs.

## Correction (portal naming)

| Field | Table | Meaning |
|-------|-------|---------|
| `portal_name` | `user_iptv_portals` | User-chosen label for this profile (only cloud display name) |

Global `iptv_portals` stores credentials / expiry / max connections only — no display-name column.

## Related

- [RFC-006](006-[partial]-supabase-sync.md) — prior sync domains (historical rows frozen)
- [RFC-034](034-[partial]-web-portal-landing.md) — web portal
