# RFC-037: Web portal French + Arabic i18n

**Status:** open  
**Depends on:** RFC-034  
**Area:** `apps/web/src/`

## Status at a glance

| | |
|--|--|
| **Progress** | **0 / 4** components · **0 / 8** acceptance (web UI) · **0 / 1** Flutter deferred |
| **Current slice** | Web-first `react-i18next` — EN / FR / AR + Arabic RTL |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R37-C01 | `i18next` + locale persistence + `html` lang/dir | ⬜ |
| 2 | R37-C02 | Message catalogs `en` / `fr` / `ar` under `apps/web/src/locales/` | ⬜ |
| 3 | R37-C03 | Language switcher in site header | ⬜ |
| 4 | R37-C04 | Arabic RTL layout pass (logical spacing, toggles, shells) | ⬜ |

---

## Acceptance (web UI)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R37-A01 | Marketing pages (landing, IPTV, download) localized | ⬜ |
| 2 | R37-A02 | Auth pages + auth story panel + auth errors localized | ⬜ |
| 3 | R37-A03 | Account + settings shell + settings pages localized | ⬜ |
| 4 | R37-A04 | Legal shell + terms/DMCA chrome localized | ⬜ |
| 5 | R37-A05 | Document title/description follow locale | ⬜ |
| 6 | R37-A06 | Locale persists across refresh (`localStorage`) | ⬜ |
| 7 | R37-A07 | Arabic sets `dir="rtl"` and layouts read correctly | ⬜ |
| 8 | R37-A08 | Changelog + feature docs updated for language switcher | ⬜ |

---

## Acceptance (Flutter — deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R37-A09 | Flutter app adopts same key names for UI locale | ⏭️ |

---

## Summary

Localize the web portal UI into English (default), French, and Arabic using web-owned JSON catalogs and `react-i18next`. No shared monorepo catalog package. Flutter reuse is a later slice using the same key naming convention.

## Goals

1. Full user-facing web UI in EN / FR / AR.
2. Persist locale preference; first visit may follow browser language.
3. Arabic RTL without redesigning Liquid Glass.
4. Stable dotted keys (`nav.*`, `auth.*`, `settings.*`) for future Flutter adoption.

## Out of scope

- Shared `packages/i18n` catalog
- Path-prefixed routes (`/fr/...`)
- Supabase Auth email HTML templates
- Changelog markdown release-note bodies
- Flutter `MaterialApp` locale wiring (R37-A09)

## Related

- [RFC-034](034-[partial]-web-portal-landing.md) — web portal
- [Backlog 1.0.4](../backlog/1.0.4-[draft].md)
