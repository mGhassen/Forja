# 341 — CinemaCity empty Sources (stale DLE cookie + guest gate)

**Status:** open  
**Priority:** P1  
**Severity:** High  
**Area:** `forja-packs/providers/cinemacity.js` · Sources Forja

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 4** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I341-T01 | Probe live `cinemacity.cc` — confirm guest gate, dead SPECS cookie, search 403 | ✅ |
| 2 | I341-T02 | Rotate `SPECS.cookie` (`dle_user_id` / `dle_password`) to a working session | ⬜ |
| 3 | I341-T03 | Retarget search off dead `/?do=search…` (guest 403) — logged-in `dle_search` ajax and/or `news_pages.xml` title match | ⬜ |
| 4 | I341-T04 | Providers pack bump + host string test + changelog | ⬜ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I341-A01 | Live probe: logged-in cookie → movie page Playerjs `file:` non-empty HLS/MP4; extract returns ≥1 stream | ⬜ |
| 2 | I341-A02 | App: Sources → CinemaCity lists playable streams (manual) | ⬜ |

---

## Summary

CinemaCity Forja extract hardcodes a DLE session cookie:

`dle_user_id=32729; dle_password=894171c6a8dab18ee594d5c652009a35`

Live site rejects that session. Guests see **Sign in to watch** / **Guests are not allowed to watch or download**. Player init still runs through `atob`, but with **`file:""`** — so extract finds no playable URL and returns `[]`.

Separately, guest search is gated:

- Classic `/?do=search&subaction=search&story=…` → **HTTP 403** (empty body)
- Site JS (`libs.js`) documents **fake search for guests** — submit opens the login modal instead of querying
- Live search module is `POST /engine/mods/dle_search/ajax.php` (needs `dle_hash`); also **403** while logged out

Cloudflare managed challenge also blocks bare curl / many headless clients (`Just a moment…`). Browser sessions that clear CF still hit the login wall without a valid cookie.

### Blocked on

A working CinemaCity account cookie (or credentials to mint one). Cannot ship streams without it — empty `file:` is intentional for guests.

### Related

- [stream providers](../../features/sources/stream-providers.md)
- [RFC-060](../rfc/fixed/060-[fixed]-enginejs-sources-forja-tab.md)
