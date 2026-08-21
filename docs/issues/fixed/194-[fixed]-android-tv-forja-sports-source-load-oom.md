# 194 — Android TV Forja Sports source load kills process

**Priority:** P1  
**Severity:** High  
**Status:** fixed  
**Area:** Live Matches · Forja Sports · `crates/live-matches` · Android TV  
**Reported:** 2026-08-21

## Status at a glance

| | |
|--|--|
| **Progress** | **Complete · 3 / 3** fix · **1 / 2** acceptance |

**Legend:** ✅ done · 🔄 in progress · ⬜ not started

---

## Fix tasks

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I194-T01 | Cap short-EPG concurrency (12) + max fetches (120) with name/sports prefilter | ✅ |
| 2 | I194-T02 | Skeleton candidates first; EPG only on prefiltered indices | ✅ |
| 3 | I194-T03 | ATV All: serialize Forja Sports then Stremio (no parallel resolve) | ✅ |

---

## Acceptance

| # | ID | Description | Status |
|--:|----|-------------|--------|
| 1 | I194-A01 | Unit: `indices_for_epg` prefers name hits and never pads past scored set | ✅ |
| 2 | I194-A02 | Manual ATV: Live Matches → All → open match → Sources panel fills without process kill | ⬜ |

---

## Summary

Opening a Live Matches card on **Android TV** (All / Forja Sports path) showed **Loading sources…** / Sources panel then **Lost connection to device** — process killed.

**Root cause:** `sport_match_streams` downloaded the full Xtream live list, then spawned an **unbounded** `JoinSet` of `get_short_epg` HTTP calls per channel. With empty `sportCategories` (no Settings mapper UI yet) that is the entire bouquet. Parallel Stremio catalog/stream fetch on the same tap stacked more pressure on leanback RAM/FDs.

**Root fix:** name/sports prefilter + hard EPG caps + bounded concurrency in Rust; ATV All resolves Forja Sports then Stremio sequentially.

**Still open:** category-map UI (RFC-062) so matching does not scan the whole bouquet for skeletons; ATV manual smoke `I194-A02`.

**Related:** [RFC-062](../rfc/062-[open]-native-iptv-sports-matching.md)
