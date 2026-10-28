# 512 — IPTV EPG view button does nothing

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** desktop · IPTV Live · kit layout  
**Reported:** 2026-10-28 (manual — Cards/EPG click left channel cards)

## Status at a glance

| | |
|--|--|
| **Progress** | **1 / 1** fix · **0 / 1** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Symptom

On desktop IPTV Live, the top-bar **EPG** (View) control selects but the channel pane stays on cards — no `CatalogEpgGuide`.

## Root cause

Host remaps chrome View → list style only when `kit.list` opts in with `viewMenu` ([434](434-[fixed]-live-sports-sports-tv-shelf.md) I434-T11). IPTV `hubs/iptv/_layout.js` emitted the View action but omitted `viewMenu: 'view'` on the items list (Live Sports already had it).

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I512-T01 | IPTV items list: `viewMenu: 'view'` + pack version bump | ✅ |

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I512-A01 | Desktop Live: Cards ↔ EPG switches the channel pane (wide width, EPG setting on) | ⬜ |

## Links

- [RFC-041](../../rfc/041-[open]-iptv-live-epg-guide.md) (R41-A01)
- [434](434-[fixed]-live-sports-sports-tv-shelf.md) (`viewMenu` gate)
