# RFC-041: IPTV Live EPG guide view

**Status:** open  
**Depends on:** [RFC-002](fixed/002-[fixed]-iptv-groups.md), [RFC-027](027-[draft]-iptv-channel-guide.md) (in-player guide — separate)  
**Area:** `features/iptv/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **0 / 6** acceptance (desktop — code landed, manual QA open) |
| **Current slice** | Cards ↔ EPG toggle in Live catalog channel pane |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R41-C01 | Xtream `get_simple_data_table` + session window cache | ✅ |
| 2 | R41-C02 | Live browse layout mode (cards / guide) + device prefs | ✅ |
| 3 | R41-C03 | Desktop EPG grid (frozen channels + ruler + Now line) | ✅ |
| 4 | R41-C04 | Top-bar view toggle next to Live shelf | ✅ |

---

## Acceptance (desktop)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R41-A01 | Live catalog: pill toggles Cards ↔ EPG in the channel pane (not a new route) | ⬜ |
| 2 | R41-A02 | Guide window = 6h behind · 24h ahead; programmes sized by duration | ⬜ |
| 3 | R41-A03 | Sticky channel column + sticky half-hour ruler + red Now marker | ⬜ |
| 4 | R41-A04 | Data from `get_simple_data_table` (session-cached); respects IPTV EPG setting | ⬜ |
| 5 | R41-A05 | Tap channel or programme → live play (no catchup) | ⬜ |
| 6 | R41-A06 | Movies / Series / TV profile / compact width — cards only (no toggle) | ⬜ |

---

## Summary

Add a Lume-style programme guide as an alternate **view mode** for the Live catalog channel pane. Categories stay; only the right pane switches between the existing card/list grid and a 2D EPG timeline.

## Goals

1. Browse what’s on now / next hours without leaving the catalog.
2. Reuse Xtream full-channel EPG (`get_simple_data_table`), not XMLTV sync.
3. Desktop-first; TV D-pad and catchup out of scope.

## Out of scope (this slice)

- Catchup / timeshift playback from past blocks
- TV / mobile EPG grid
- External XMLTV sources
- In-player guide EPG rows (RFC-027)

## Related

- [iptv-xtream.md](../features/live/iptv-xtream.md)
- Lume LiveTV EPG (reference UX only — AGPL; do not copy code)
