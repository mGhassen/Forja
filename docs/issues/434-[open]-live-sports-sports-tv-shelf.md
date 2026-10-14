# Issue 434 — Live Sports Sports / TV shelf

**Status:** open  
**Priority:** P2  
**Severity:** Medium

## Status at a glance

| Field | Value |
|-------|--------|
| Progress | 🔄 pack + host |
| Components | 0/5 |
| Acceptance | 0/4 |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Problem

Live Sports mixes match schedule and 24/7 channels in one feed with sport circles. IPTV already uses a top shelf. 24/7 should live on a **TV** shelf with IPTV-sized channel cards and tap-to-play (no panel, no details, no Live TV merge).

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I434-T01 | Pack shelf Sports / TV + Sports chrome vs TV Search+Refresh | 🔄 |
| 2 | I434-T02 | Pack feed split: Sports excludes 24/7; TV is 24/7 only, no merge, channelCard paint | 🔄 |
| 3 | I434-T03 | Host `sectionMenu` + topBody child `showWhen` (hide kind bar / swap lists) | 🔄 |
| 4 | I434-T04 | Host `open: play` — resolve Providers only, play first stream | 🔄 |
| 5 | I434-T05 | Feature guide + changelog | ⬜ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I434-A01 | Sports shelf: current schedule UI, no 24/7 rows or chips | ⬜ |
| 2 | I434-A02 | TV shelf: no kind bar; chrome is shelf + Search + Refresh | ⬜ |
| 3 | I434-A03 | TV cards are IPTV channel size; tap plays without panel/details/Live TV merge | ⬜ |
| 4 | I434-A04 | TV rows are not merge-collapsed across catalogs | ⬜ |

---

## Related

- Feature: [Live Sports](../features/live/live-sports.md)
- Peer shelf: IPTV Live / Movies / Series
