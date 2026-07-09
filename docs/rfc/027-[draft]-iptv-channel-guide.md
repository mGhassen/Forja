# RFC-027: IPTV in-player channel guide

**Status:** draft  
**Depends on:** [RFC-002](fixed/002-[fixed]-iptv-groups.md) (Xtream categories)  
**Area:** `features/iptv/`

## Status at a glance

| | |
|--|--|
| **Progress** | **4 / 4** components · **1 / 4** acceptance |
| **Current slice** | Xtream live + M3U in-player zapping |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R27-C01 | `IptvChannelGuide` model + Xtream/M3U factories | ✅ |
| 2 | R27-C02 | `IptvChannelGuidePanel` — dual columns desktop, drill-down mobile | ✅ |
| 3 | R27-C03 | `IptvPtPlayerScreen` channel switch + guide toggle | ✅ |
| 4 | R27-C04 | Xtream live + M3U entry handoff | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R27-A01 | Desktop: groups + channels panels overlay video; zap without pop | ⬜ |
| 2 | R27-A02 | Mobile: drill-down groups → channels with back | ⬜ |
| 3 | R27-A03 | VOD / series / Channels Hub — no guide button | ⬜ |
| 4 | R27-A04 | `flutter analyze` clean on touched IPTV files | ✅ |

---

## Summary

Add an in-player channel guide overlay for IPTV live zapping: left groups panel, right channels panel (desktop), drill-down on phone. Snapshot passed at navigation — no live `IptvController` coupling.

## Goals

- Change live channels without leaving the player
- Reuse browser category visual language
- Xtream live + M3U playlists only

## Out of scope (v1)

- Channels Hub branded search
- EPG rows in guide
- Keyboard ch+/ch−
- Live session sync with browser after player opens

## Related

- [iptv-xtream.md](../features/live/iptv-xtream.md)
- [iptv-m3u.md](../features/live/iptv-m3u.md)
