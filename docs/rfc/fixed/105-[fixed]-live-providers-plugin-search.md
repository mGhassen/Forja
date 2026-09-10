# RFC-105: Providers — plugin-owned fixture search + progressive paint

**Status:** fixed  
**Depends on:** [RFC-065](../065-[open]-live-forja-scrapers.md) · [Issue 254](../../issues/254-[open]-live-catalog-schedule-only-no-streams.md)  
**Area:** live packs · Providers panel · engine host

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete** · **3 / 3** components · **6 / 6** acceptance |
| **Current slice** | Host fan-out + progressive; pack fixture search (WatchFooty / StreamFree / PPV / Streamic / TimStreams) |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started · ⏭️ deferred (later slice)

---

## Components

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R105-C01 | Host Providers fans out enabled **resolve** plugins with fixture identity (no catalog-pool soft-match) | ✅ |
| 2 | R105-C02 | Kit Sources panel paints rows as each resolve returns | ✅ |
| 3 | R105-C03 | Live packs search own upstream by title/teams/date when `matchId` is foreign/missing | ✅ |

---

## Acceptance (slice)

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | R105-A01 | Host does **not** soft-match the remembered All-catalog pool for Providers | ✅ |
| 2 | R105-A02 | Host calls every enabled resolve-capable plugin with fixture fields (+ opaque `matchId`/`source` only when that pack owns the opened row) | ✅ |
| 3 | R105-A03 | Providers list paints the first real mirrors as soon as any pack returns (progressive) | ✅ |
| 4 | R105-A04 | Pack `resolve` finds its own fixture (teams/title/date) when foreign/missing id | ✅ |
| 5 | R105-A05 | Catalog capability stays schedule-only; resolve capability owns stream discover | ✅ |
| 6 | R105-A06 | Feature doc + changelog | ✅ |

---

## Summary

**Wrong:** Host soft-matches schedule siblings across catalogs, then N× `runLivePlugin(resolve)` with stolen ids — pack knowledge in the app.

**Right:** Host is engine + UI. It lists resolve-capable plugins, fans out fixture identity in parallel, paints progressively. Each **live pack** searches its own upstream and returns mirrors (or `[]`). Catalog vs resolve is a pack capability (`catalog` / `resolve`), not a host search algorithm.

### Host contract (`action: resolve` params)

```json
{
  "title": "…",
  "homeTeam": "…",
  "awayTeam": "…",
  "dateMs": 0,
  "eventId": "opaque opened id",
  "category": "football",
  "matchId": "optional — only when this pack owns the source ref",
  "source": "optional — pack resolveSource token"
}
```

### Related

- [RFC-065](../065-[open]-live-forja-scrapers.md) — live scrapers / capabilities  
- [Issue 254](../../issues/254-[open]-live-catalog-schedule-only-no-streams.md) — catalog schedule-only  
