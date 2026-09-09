# Issue 254: Live catalog must be schedule-only (no stream find / resolve)

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** live sports / catalog packs / Providers

## Status at a glance

| | |
|--|--|
| **Progress** | **7 / 7** fix · **0 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I254-T01 | Host drops catalog `streams[]` / `iframe` / `url` on schedule ingest (`MatchEvent.fromLegacyRow`, feed meta) | ✅ |
| 2 | I254-T02 | Providers soft-match only `providerId` catalogs; never promote catalog embeds into stream rows | ✅ |
| 3 | I254-T03 | Pending unlock calls live resolve with `matchId` / `eventId` (no catalog iframe required) | ✅ |
| 4 | I254-T04 | Catalog packs strip embed payloads (PPV / TimStreams / Streamic / MobiKora); opaque `sources[{source,id}]` only | ✅ |
| 5 | I254-T05 | Cursor rule + feature / changelog wording: catalog = schedule, live = discover+unlock | ✅ |
| 6 | I254-T06 | Host unit test: schedule-only ingest + provider-feed gate (synthetic fixtures) | ✅ |
| 7 | I254-T07 | Providers never invents `pending:` rows — discover real live mirrors only (WatchFooty list / Streamed list / live resolve); empty upstream → no Providers row | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I254-A01 | Manual: Providers lists Streamed / PPV / … mirrors without Live Soccer TV / LiveOnSat; play unlocks via live pack | ⬜ |
| 2 | I254-A02 | Manual: WatchFooty (or peer) fixture with site `Stream links (0)` shows no fake provider row; catalog still lists the match | ⬜ |

---

## Summary

Catalog packs (`plugins/catalog/**`) are **schedule only**. They must not discover stream mirrors, ship embed URLs, or resolve playback. Live packs (`plugins/live/**`) own stream listing and unlock.

**Root cause:** Providers soft-match treated every catalog sibling as a resolver, and schedule rows carried `iframe` / `streams[]` that the host painted as Sources.

**Contract after fix:**

| Layer | Allowed | Forbidden |
|-------|---------|-----------|
| Catalog row | `id`, title, time, teams, opaque `sources[{source,id}]`, broadcast hints — **all** schedule fixtures incl. no links yet | `streams[]`, `iframe`, `embedUrl`, `streamCount` |
| Host Providers | Soft-match → live discover (Streamed list / WatchFooty stream list / live resolve) — **only real mirrors** | Catalog embeds; invented `pending:` / preparing rows when upstream has 0 links |
| Live pack | `action: resolve` (+ Streamed / WatchFooty list) | — |

Broadcast-only catalogs (Live Soccer TV, LiveOnSat) stay out of Providers entirely.

## Related

- [live-sports feature](../features/live/live-sports.md)
- [no-embed-playback](../../.cursor/rules/no-embed-playback.mdc)
- [RFC-065](../rfc/065-[open]-live-forja-scrapers.md)
