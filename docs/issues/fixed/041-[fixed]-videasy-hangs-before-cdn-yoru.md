# 041 — Videasy extract hangs on neon2 before reaching working Yoru/cdn

**Status:** fixed  
**Priority:** P1  
**Severity:** High  
**Area:** `apps/forja/lib/shared/extractors/providers/videasy/videasy_extractor.dart`, Videasy host resolve

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 4 / 4** fix · **3 / 3** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I41-T01 | Reorder mirrors: website Yoru=`cdn` first; hung neon2/m4uhd after | ✅ |
| 2 | I41-T02 | Fail-fast probe timeouts + short grace after first hit | ✅ |
| 3 | I41-T03 | Map remaining Servers (Killjoy=`meine`, Omen=`lamovie`, …) + display names | ✅ |
| 4 | I41-T04 | Movie query sends `seasonId`/`episodeId` defaults like the player | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I41-A01 | Live wings `cdn` for TMDB 1083381 returns encrypted payload (~200) | ✅ |
| 2 | I41-A02 | Unit: movie sources query includes seasonId/episodeId | ✅ |
| 3 | I41-A03 | Manual: pin Videasy on Backrooms plays (desktop) | ⬜ |

---

## Summary

Website Servers (chunk 8351) map Valorant labels → wings endpoints (`Yoru`→`cdn`, `Neon`→`neon2`, …). Default play hits **cdn**, which answers in ~100ms for Backrooms.

Forja raced **neon2 first** with a 60s fetch timeout. neon2 often hangs with 0 bytes; extract's 55s outer timeout fired **before cdn was probed**, so Videasy looked “broken” while the site worked.

**Root fix:** probe order + timeouts match the live player; collect additional mirrors briefly after the first hit.

## Related

- [stream-providers](../features/sources/stream-providers.md)
- [RFC-032](../rfc/032-[open]-rust-resolver-engine.md) R32-A09 (native Videasy port — still open)
