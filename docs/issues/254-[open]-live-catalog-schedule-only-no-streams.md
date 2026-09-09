# Issue 254: Live catalog must be schedule-only (no stream find / resolve)

**Status:** open  
**Priority:** P0  
**Severity:** High  
**Area:** live sports / catalog packs / Providers

## Status at a glance

| | |
|--|--|
| **Progress** | **6 / 6** fix · **0 / 1** acceptance |

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

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I254-A01 | Manual: Providers lists Streamed / PPV / … mirrors without Live Soccer TV / LiveOnSat; play unlocks via live pack | ⬜ |

---

## Summary

Catalog packs (`plugins/catalog/**`) are **schedule only**. They must not discover stream mirrors, ship embed URLs, or resolve playback. Live packs (`plugins/live/**`) own stream listing and unlock.

**Root cause:** Providers soft-match treated every catalog sibling as a resolver, and schedule rows carried `iframe` / `streams[]` that the host painted as Sources.

**Contract after fix:**

| Layer | Allowed | Forbidden |
|-------|---------|-----------|
| Catalog row | `id`, title, time, teams, opaque `sources[{source,id}]`, broadcast hints | `streams[]`, `iframe`, `embedUrl`, `streamCount` |
| Host Providers | Soft-match → live pack resolve / Streamed list API | Catalog embeds as play URLs |
| Live pack | `action: resolve` (+ Streamed list) | — |

Broadcast-only catalogs (Live Soccer TV, LiveOnSat) stay out of Providers entirely.

## Related

- [live-sports feature](../features/live/live-sports.md)
- [no-embed-playback](../../.cursor/rules/no-embed-playback.mdc)
- [RFC-065](../rfc/065-[open]-live-forja-scrapers.md)
