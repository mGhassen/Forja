# RFC-096: IPTV channel search only — pack owns sports policy

**Status:** open  
**Depends on:** [RFC-062](062-[open]-native-iptv-sports-matching.md) · [RFC-092](fixed/092-[fixed]-delete-root-app-live-sports.md) · [RFC-095](fixed/095-[fixed]-foundation-design-data-split.md)  
**Area:** `features/iptv/channel_search/`, Live Sports hub packs, engine host bridge

## Status at a glance

| | |
|--|--|
| **Progress** | **3 / 3** components · **8 / 8** acceptance · **0 / 1** deferred |
| **Current slice** | Host cut shipped — thin `IptvChannelSearch`; portal sports config/match deleted |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R96-C01 | `IptvChannelSearch` — portal resolve + `sport_match_streams` + URL/logo enrich + cache | ✅ |
| 2 | R96-C02 | `IptvForjaSportsGate` — pack `forjaSportsEnabled` only (no leagues/maps) | ✅ |
| 3 | R96-C03 | JS bridge `ctx.host.iptv.searchChannels` | ✅ |

---

## Acceptance (host cut)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R96-A01 | No `IptvPortalSportsConfig` / `IptvPortalSportsMatchService` / `portal_sports/` | ✅ |
| 2 | R96-A02 | Live TV resolve builds `game` from pack `sportMatchGame` or row title/teams passthrough | ✅ |
| 3 | R96-A03 | Host has no NBA/league/sportFamily maps and no broadcast soft-match index | ✅ |
| 4 | R96-A04 | Portals chip gates on pack `forjaSportsEnabled`; no `ensureArmed` | ✅ |
| 5 | R96-A05 | Hub feed rows expose `sportMatchGame` when missing (pack-owned) | ✅ |
| 6 | R96-A06 | `ctx.host.iptv.searchChannels` available next to `liveFeed` | ✅ |
| 7 | R96-A07 | Feature + services-map + RFC-062 note updated | ✅ |
| 8 | R96-A08 | `dart analyze` clean on touched IPTV / engine paths | ✅ |

---

## Acceptance (deferred)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 9 | R96-A09 | Full JS-only Live TV resolve via hub action + `searchChannels` | ⏭️ |

---

## Summary

Host IPTV sports surface is **channel search only**: portal credentials, Rust `sport_match_streams`, URL rebuild, logo enrich, short cache. Pack owns `forjaSportsEnabled`, leagues, merge, and the opaque `game` / `sportMatchGame` on schedule rows.

### Contract

```dart
IptvChannelSearch.search({
  required Map<String, dynamic> game,
  List<String> categoryIds = const [],
  String? portalKey,
}) → Future<List<IptvPlaySource>>
```

### Related

- [RFC-062](062-[open]-native-iptv-sports-matching.md) — Rust matcher + EPG (engine); host policy superseded here
- [live-sports.md](../features/live/live-sports.md)
